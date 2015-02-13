PositiveResults = [
  'then'
  'all'
  'some'
  'always'
  'finally'
  'contest'
  'race'
  'root'
]
NegativeResults = [
  'else'
  'finally'
  'always'
]

trees = 0

Thenable = require './Thenable'
{State} = require './state'

class BehaviorTree
  constructor: (@name, @options = {}) ->
    @id = trees++
    @nodes =
      root:
        id: 'root'
        name: @name
        type: 'root'
        choices: {}
        sources: []
        destinations: []
        branches: []
    @parentOnBranch = null

  onSubtree: (choice, name, continuation, callback) =>
    tree = new BehaviorTree name, @options
    tree.parentOnBranch = choice.parentOnBranch or @parentOnBranch
    tree.continuation = continuation
    t = new Thenable tree
    choice.subtrees = [] unless choice.subtrees
    choice.subtrees.push tree

    node = tree.nodes['root']
    node.parentSource = choice
    subChoice = new @options.Choice null, 'root', name
    node.choices[''] = subChoice
    node.choices[''].onSubtree = tree.onSubtree
    node.choices[''].parentSource = choice
    node.choices[''].parentOnBranch = @parentOnBranch

    callback t, tree if callback
    t

  onBranch: (orig, branch, callback) =>
    unless @parentOnBranch
      throw new Error "Tree #{@id} is not within a branchable context (some, all, contest, race)"
    originalNode = @nodes[orig.id]
    unless originalNode
      throw new Error "Source node #{orig.id} not found"
    @parentOnBranch @, orig, branch, callback
    id = @registerNode originalNode.promiseSource, branch.name, originalNode.type, callback, false
    sourcePath = if orig.source then orig.source.toString() else ''
    destPath = branch.toString()
    @nodes[id].choices[sourcePath] = branch
    @nodes[id].destinations = originalNode.destinations.slice 0
    originalNode.branches = [] unless originalNode.branches
    originalNode.branches.push @nodes[id]

    # Trigger re-resolve to cause the new branch to be run
    @resolve originalNode.promiseSource, sourcePath

  createId: (name, seq = 0) ->
    id = name.replace /-/g, '_'
    unless @nodes[id]
      # First choice with the given name
      return id

    seq++
    seqId = "#{id}_#{seq}"
    while @nodes[seqId]
      seq++
      seqId = "#{id}_#{seq}"
    seqId

  registerNode: (source, name, type, callback, autoresolve = true) ->
    unless callback
      type = name
      callback = type
      name = null

    id = @createId name or type

    unless @nodes[source]
      throw new Error "Unknown source #{source} for choice #{id}"

    @nodes[id] =
      id: id
      name: name
      promiseSource: source
      type: type
      callback: callback
      choices: {}
      sources: []
      destinations: []
      branches: []

    @findSources @nodes[id], autoresolve

    id

  executeNode: (sourceChoice, id, data) ->
    unless @nodes[id]
      throw new Error "Unknown node #{id}"
    node = @nodes[id]
    unless typeof node.callback is 'function'
      throw new Error "Node #{id} is not executable"
    sourcePath = sourceChoice.toString()
    unless node.choices[sourcePath]
      choice = new @options.Choice sourceChoice, id, node.name
      choice.onBranch = @onBranch
      choice.onSubtree = @onSubtree
      choice.parentOnBranch = @parentOnBranch
      node.choices[sourcePath] = choice
    choice = node.choices[sourcePath]
    localPath = node.choices[sourcePath].toString()
    return if choice.state in [State.ABORTED, State.RUNNING]
    choice.state = State.RUNNING
    try
      val = node.callback choice, data
      if val and typeof val.then is 'function' and typeof val.else is 'function'
        # Thenable returned, make subtree
        choice.subtrees = [] unless choice.subtrees
        choice.subtrees.push val.tree
        val.then (c, r) =>
          choice.set 'data', r
          choice.state = State.FULFILLED
          c.continuation = val.tree.continuation
          choice.registerSubleaf c, true
          @resolve node.id, sourcePath
        val.else (c, e) =>
          choice.set 'data', e
          choice.state = State.REJECTED
          c.continuation = val.tree.continuation
          choice.registerSubleaf c, false
          @resolve node.id, sourcePath
        return
      # Straight-up value returned
      choice.set 'data', val
      choice.state = State.FULFILLED
      @resolve node.id, sourcePath
    catch e
      # Rejected
      return if choice.state is State.ABORTED
      choice.set 'data', e
      choice.state = State.REJECTED
      @resolve node.id, sourcePath

  resolve: (id, sourcePath = '') ->
    node = @nodes[id]
    return unless node
    choice = node.choices[sourcePath]
    return unless choice
    return unless choice.state in [State.FULFILLED, State.REJECTED]
    val = choice.get 'data'
    throw val if node.type is 'finally' and choice.state is State.REJECTED

    localPath = choice.toString()
    dests = @findDestinations node, choice
    dests.forEach (d) =>
      destChoice = d.choices[localPath]
      if destChoice and destChoice.state isnt State.PENDING
        return
      @executeNode choice, d.id, val

  execute: (data, state = State.FULFILLED) ->
    node = @nodes['root']
    choice = @nodes['root'].choices[''] or new @options.Choice node.id
    choice.onBranch = @onBranch
    choice.onSubtree = @onSubtree
    choice.parentOnBranch = @parentOnBranch
    choice.parentSource = @nodes['root'].parentSource
    if typeof data is 'object' and toString.call(data) isnt '[object Array]'
      for key, val of data
        choice.set key, val
    choice.set 'data', data
    choice.state = state
    node.choices[''] = choice
    @resolve node.id, ''

  findDestinations: (node, choice) ->
    node.destinations.filter (d) ->
      if choice.state is State.REJECTED and d.type in NegativeResults
        return true
      if choice.state is State.FULFILLED and d.type in PositiveResults
        return true
      false

  findSources: (choice, autoresolve) ->
    gotNegative = false
    gotPositive = false

    source = @nodes[choice.promiseSource]
    while source
      if gotPositive and source.type in PositiveResults
        # Skip this one, keep looking for a negative
        source = @nodes[source.promiseSource]
        continue
      if gotNegative and source.type in NegativeResults
        # Skip this one, keep looking for a positive
        source = @nodes[source.promiseSource]
        continue

      # Add edge between source and node
      source.destinations.push choice if source.destinations.indexOf(choice) is -1
      choice.sources.push source if choice.sources.indexOf(source) is -1

      if source.branches and source.branches.length
        for branch in source.branches
          choice.sources.push branch if choice.sources.indexOf(branch) is -1
          branch.destinations.push choice if branch.destinations.indexOf(choice) is -1
          for path, c of branch.choices
            @resolve branch.id, path if autoresolve

      for path, c of source.choices
        @resolve source.id, path if autoresolve

      break if source.type is 'root'
      if choice.type in ['then', 'all', 'some', 'contest', 'race'] and source.type in PositiveResults
        break
      if choice.type is 'else' and source.type in NegativeResults
        break
      if choice.type in ['always', 'finally'] and source.type in PositiveResults
        gotPositive = true
        break if gotNegative
      if choice.type is ['always', 'finally'] and source.type in NegativeResults
        gotNegative = true
        break if gotPositive
      source = @nodes[source.promiseSource]
    choice.sources

  toDOT: ->
    trees = {}
    register = (t, node) ->
      subtrees = []
      if node.choice?.subtrees?.length
        subtrees = node.choice.subtrees.map toVisual
      t.addNode node.id, node.name, node.choice?.attributes, node.choice?.state, subtrees
      for d in node.sources
        state = State.PENDING
        if node.choice and node.choice.source
          state = node.choice.state if node.choice.source.id is d.id
        t.addEdge d.id, node.id, node.type, state
      for d in node.destinations
        register t, d
    toVisual = (tree) ->
      return unless tree
      return trees[tree.id] if trees[tree.id]
      Tree = require './tree'
      t = new Tree tree.name
      register t, tree.nodes['root']
      t

    t = toVisual @
    t.toDOT()

module.exports = BehaviorTree
