PositiveResults = [
  'then'
  'all'
  'some'
  'always'
  'finally'
  'contest'
  'race'
  'maybe'
  'root'
]
NegativeResults = [
  'else'
  'finally'
  'always'
]

trees = 0

Thenable = require './Thenable'
{State, stateToString, isActive} = require './state'
chai = require 'chai'
debug = require 'debug'
log =
  tree: debug 'tree'
  errors: debug 'errors'
graphlib = require 'graphlib'
dot = require 'graphlib-dot'

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
    @directOnAbort = false
    @aborted = []

  onSubtree: (choice, name, continuation, callback) =>
    log.tree "#{@name or @id} new subtree #{name} from #{choice}"
    tree = new BehaviorTree name, @options
    tree.parentOnBranch = choice.parentOnBranch or @parentOnBranch

    onAbort = choice.onAbort or @onAbort
    onAbort = null if @directOnAbort
    unless onAbort
      onAbort = (rChoice, reason, value, branched) =>
        return if branched
        log.tree "#{@name or @id} Non-collection #{rChoice} aborted with %s", reason
        tree.aborted.push
          choice: rChoice
          reason: reason
          value: value
      tree.directOnAbort = true

    tree.onAbort = onAbort
    t = new Thenable tree
    choice.subtrees = [] unless choice.subtrees
    choice.subtrees.push tree

    node = tree.nodes['root']
    node.parentSource = choice
    subChoice = new @options.Choice null, 'root', name
    subChoice.treeId = tree.id
    node.choices[''] = subChoice
    node.choices[''].onSubtree = tree.onSubtree
    node.choices[''].parentSource = choice
    node.choices[''].parentOnBranch = @parentOnBranch
    node.choices[''].onAbort = tree.onAbort
    node.choices[''].continuation = continuation

    callback t, tree if callback
    t

  onBranch: (orig, branch, callback) =>
    log.tree "#{@name or @id} Branch #{branch} from #{orig}"
    if orig.id is 'root'
      throw new Error 'Cannot branch the root node'
    originalNode = @nodes[orig.id]
    unless originalNode
      throw new Error "Source node #{orig.id} not found"
    @parentOnBranch @, orig, branch, callback if @parentOnBranch
    id = @registerNode originalNode.promiseSource, branch.name, originalNode.type, callback, false
    sourcePath = if orig.source then orig.source.toString() else ''
    destPath = branch.toString()
    branch.treeId = @id
    @nodes[id].choices[sourcePath] = branch
    @nodes[id].destinations = originalNode.destinations.slice 0
    originalNode.branches = [] unless originalNode.branches
    originalNode.branches.push @nodes[id]

    # Trigger re-resolve to cause the new branch to be run
    sourcePath = '' if originalNode.promiseSource is 'root'
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

  insertNodeAfter: (source, name, type, callback) ->
    unless callback
      type = name
      callback = type
      name = null

    id = @createId name or type

    sourceNode = @nodes[source]
    unless sourceNode
      throw new Error "Unknown source #{source} for choice #{id}"

    @nodes[id] =
      id: id
      name: name
      promiseSource: source
      type: type
      callback: callback
      choices: {}
      sources: [sourceNode]
      destinations: sourceNode.destinations.slice 0
      branches: []
    sourceNode.destinations = [@nodes[id]]
    sourceNode.after = @nodes[id]

    id

  executeNode: (sourceChoice, id, data) ->
    log.tree "#{@name or @id} Execute #{sourceChoice} #{stateToString(sourceChoice.state)} -> #{id}"
    unless @nodes[id]
      throw new Error "Unknown node #{id}"
    node = @nodes[id]
    unless typeof node.callback is 'function'
      throw new Error "Node #{id} is not executable"
    sourcePath = sourceChoice.toString()
    unless node.choices[sourcePath]
      choice = new @options.Choice sourceChoice, id, node.name
      choice.treeId = @id
      choice.onBranch = @onBranch
      choice.onSubtree = @onSubtree
      choice.parentOnBranch = @parentOnBranch
      choice.onAbort = @onAbort
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
          choice.set 'data', r if isActive choice
          choice.state = State.FULFILLED if isActive choice
          c.continuation = val.tree.getRootChoice().continuation
          choice.registerSubleaf c, true
          @resolve node.id, sourcePath
        val.else (c, e) =>
          log.errors "#{@name or @id} #{c} resulted in %s", e.message
          choice.set 'data', e if isActive choice
          choice.state = State.REJECTED if isActive choice
          c.continuation = val.tree.getRootChoice().continuation
          choice.registerSubleaf c, false
          @resolve node.id, sourcePath

        if val.tree.directOnAbort and val.tree.aborted.length and choice.state is State.RUNNING
          abort = val.tree.aborted[0]
          log.errors "#{@name or @id} #{choice} has an aborted subtree, reason: #{abort.reason}"
          choice.set 'data', abort.value if isActive choice
          choice.state = State.REJECTED if isActive choice
          choice.registerSubleaf abort.choice, false
          @resolve node.id, sourcePath

        return
      # Straight-up value returned
      choice.set 'data', val if isActive choice
      choice.state = State.FULFILLED if isActive choice
      @resolve node.id, sourcePath
    catch e
      log.errors "#{@name or @id} #{choice} resulted in %s", e.message
      # Rejected
      return if choice.state is State.ABORTED
      if e instanceof chai.AssertionError
        choice.set 'preconditionFailed', e if isActive choice
        throwVal = choice.get 'preconditionFailedData'
        e = throwVal or e
      choice.set 'data', e if isActive choice
      choice.state = State.REJECTED if isActive choice
      @resolve node.id, sourcePath

  getRoot: ->
    @nodes['root']
  getRootChoice: ->
    @getRoot().choices['']

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
      return if d.type in ['always', 'finally'] and dests.length > 1
      destChoice = d.choices[localPath]
      if destChoice and destChoice.state isnt State.PENDING
        return
      @executeNode choice, d.id, val

  execute: (data, state = State.FULFILLED) ->
    node = @nodes['root']
    choice = @nodes['root'].choices[''] or new @options.Choice node.id
    choice.treeId = @id
    choice.onBranch = @onBranch
    choice.onSubtree = @onSubtree
    choice.parentOnBranch = @parentOnBranch
    choice.onAbort = @onAbort
    choice.parentSource = @nodes['root'].parentSource
    if typeof data is 'object' and toString.call(data) isnt '[object Array]'
      for key, val of data
        choice.set key, val
    choice.set 'data', data if isActive choice
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
    source = source.after while source.after
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

  toGraph: () ->
    graphs = {}
    unless graph
      graph = new graphlib.Graph
        compound: true
        directed: true
        multigraph: true

    toGraph = (t, parent) ->
      return unless t
      return graphs[t.id] if graphs[t.id]
      graphs[t.id] = true
      # Start traversal from root of the main tree
      register t, t.nodes['root'], parent
      graphs[t.id]

    choiceToEdge = (t, n, c) ->
      edge =
        label: n.name or n.type
        name: n.name or n.type
        color: 'black'
        style: 'dotted'
      edge.style = 'solid' if c.state in [2, 3]
      edge.color = 'red' if c.state is 3

      edge

    choiceToNode = (t, n, c) ->
      node =
        label: n.name or n.type
        color: 'black'
        shape: 'box'
        style: 'dotted'
      if n.id is 'root'
        node.shape = 'Mdiamond'
      node.style = 'solid' if c?.state in [2, 3]
      node.color = 'red' if c?.state is 3
      node

    # Handler for registering node and edges based on a single behavior tree node
    register = (t, node, parent = null) ->
      nodeId = "t#{t.id}_#{node.id}"
      choices = Object.keys(node.choices).length

      for path, choice of node.choices
        if choice.subtrees?.length
          # This node has subtrees, handle accordingly
          graph.setNode "cluster_#{nodeId}", choiceToNode t, node, choice
          graph.setParent "cluster_#{nodeId}", parent if parent
          toGraph st, "cluster_#{nodeId}" for st in choice.subtrees

        # Register node
        graph.setNode nodeId, choiceToNode t, node, choice
        # Register parent if in subgraph
        graph.setParent nodeId, parent if parent

        if choice.parentSource
          fromId = "t#{choice.parentSource.treeId}_#{choice.parentSource.id}"
        if choice.source
          fromId = "t#{t.id}_#{choice.source.id}"
          if choice.source.subLeaves and choice.source.subLeaves.length
            for l in choice.source.subLeaves
              graph.setEdge "t#{l.choice.treeId}_#{l.choice.id}", nodeId,
                style: if l.accepted then 'solid' else 'dotted'
            continue

        continue unless fromId
        graph.setEdge fromId, nodeId, choiceToEdge(t, node, choice), node.name or node.type

      if node.id isnt 'root' and not choices
        # This node was never reached, mark with ignored sources
        graph.setNode nodeId, choiceToNode t, node, choice
        graph.setParent nodeId, parent if parent
        for s in node.sources
          # Don't draw edges from root to else to simplify graph
          sourceId = "t#{t.id}_#{s.id}"
          continue if s.id is 'root' and node.type is 'else'
          #continue if subgraphs[sourceId]
          graph.setEdge sourceId, nodeId,
            style: 'dotted'
            name: node.name or node.type
            label: node.name or node.type
          , node.name or node.type

      # Continue traversing the tree
      for n in node.destinations
        register t, n, parent

    toGraph @, null
    return graph

  toDOT: ->
    graph = @toGraph()
    return dot.write graph

module.exports = BehaviorTree
