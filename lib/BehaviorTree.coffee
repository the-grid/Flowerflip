PositiveResults = [
  'then'
  'all'
  'some'
  'always'
  'finally'
  'contest'
  'race'
]
NegativeResults = [
  'else'
  'finally'
  'always'
]

trees = 0

Choice = require './Choice'
Thenable = require './Thenable'
{State} = require './state'

class BehaviorTree
  constructor: (@name) ->
    @id = trees++
    @nodes =
      root:
        id: 'root'
        name: @name
        type: 'root'
        sources: []
        destinations: []
    @parentOnBranch = null

  onSubtree: (choice, name, continuation, callback) =>
    tree = new BehaviorTree name
    tree.parentOnBranch = @parentOnBranch
    tree.continuation = continuation
    t = new Thenable tree
    choice.subtrees = [] unless choice.subtrees
    choice.subtrees.push tree

    tree.nodes['root'].parentSource = choice
    tree.nodes['root'].choice = new Choice null, 'root', name
    tree.nodes['root'].choice.onSubtree = tree.onSubtree
    tree.nodes['root'].choice.parentSource = choice

    callback t, tree if callback
    t

  onBranch: (orig, branch, callback) =>
    unless @parentOnBranch
      throw new Error "Tree #{@id} is not within a branchable context (some, all, contest, race)"
    originalNode = @nodes[orig.id]
    unless originalNode
      throw new Error "Source node #{orig.id} not found"
    id = @registerNode originalNode.promiseSource, branch.name, originalNode.type, callback
    @parentOnBranch orig, branch, callback
    @nodes[id].choice = branch
    @nodes[id].destinations = originalNode.destinations.slice 0
    @resolve id

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

  registerNode: (source, name, type, callback) ->
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
      sources: []
      destinations: []

    @findSources @nodes[id]

    id

  executeNode: (sourceChoice, id, data) ->
    unless @nodes[id]
      throw new Error "Unknown node #{id}"
    node = @nodes[id]
    unless typeof node.callback is 'function'
      throw new Error "Node #{id} is not executable"
    choice = new Choice sourceChoice, id, node.name
    choice.onBranch = @onBranch
    choice.onSubtree = @onSubtree
    choice.parentOnBranch = @parentOnBranch
    node.choice = choice
    try
      val = node.callback choice, data
      return if choice.state is State.ABORTED
      if val and typeof val.then is 'function' and typeof val.else is 'function'
        # Thenable returned, make subtree
        choice.subtrees = [] unless choice.subtrees
        choice.subtrees.push val.tree
        val.then (c, r) =>
          choice.set 'data', r
          choice.state = State.FULFILLED
          c.continuation = val.tree.continuation
          choice.registerSubleaf c, true
          @resolve node.id
        val.else (c, e) =>
          choice.set 'data', e
          choice.state = State.REJECTED
          c.continuation = val.tree.continuation
          choice.registerSubleaf c, false
          @resolve node.id
        return
      # Straight-up value returned
      choice.set 'data', val
      choice.state = State.FULFILLED
      @resolve node.id
    catch e
      # Rejected
      return if choice.state is State.ABORTED
      choice.set 'data', e
      choice.state = State.REJECTED
      @resolve node.id

  resolve: (id) ->
    node = @nodes[id]
    return unless node
    return unless node.choice
    return unless node.choice.state in [State.FULFILLED, State.REJECTED]
    val = node.choice.get 'data'
    throw val if node.type is 'finally' and node.choice.state is State.REJECTED
    dests = @findDestinations node, node.choice
    dests.forEach (d) =>
      if d.choice and d.choice.state isnt State.PENDING
        return
      @executeNode node.choice, d.id, val

  execute: (data, state = State.FULFILLED) ->
    node = @nodes['root']
    choice = @nodes['root'].choice or new Choice node.id
    choice.onBranch = @onBranch
    choice.onSubtree = @onSubtree
    choice.parentOnBranch = @parentOnBranch
    choice.parentSource = @nodes['root'].parentSource
    if typeof data is 'object' and toString.call(data) isnt '[object Array]'
      for key, val of data
        choice.set key, val
    choice.set 'data', data
    choice.state = state
    node.choice = choice
    @resolve node.id

  findDestinations: (node, choice) ->
    node.destinations.filter (d) ->
      if choice.state is State.REJECTED and d.type in NegativeResults
        return true
      if choice.state is State.FULFILLED and d.type in PositiveResults
        return true
      false

  findSources: (choice) ->
    gotNegative = false
    gotPositive = false

    source = @nodes[choice.promiseSource]
    while source
      #break if source.type is 'root' and choice.type is 'else'
      source.destinations.push choice if source.destinations.indexOf(choice) is -1
      choice.sources.push source if choice.sources.indexOf(source) is -1
      @resolve source.id
      break if source.type is 'root'
      if choice.type is 'all' and source.type in PositiveResults
        break
      if choice.type is 'some' and source.type in PositiveResults
        break
      if choice.type is 'then' and source.type in PositiveResults
        break
      if choice.type is 'else' and source.type in NegativeResults
        break
      if choice.type is 'always' and source.type in PositiveResults
        gotPositive = true
        break if gotNegative
      if choice.type is 'always' and source.type in NegativeResults
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
