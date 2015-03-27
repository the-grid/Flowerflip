PositiveResults = [
  'then'
  'all'
  'some'
  'none'
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
SubtreeResults = require './SubtreeResults'
chai = require 'chai'
debug = require 'debug'
log =
  tree: debug 'tree'
  errors: debug 'errors'
  values: debug 'values'
  branch: debug 'branch'
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
    @abortedChoices = []
    @abortedCallbacks = []
    @startedChoices = []
    @startedCallbacks = []
    @branchedChoices = []
    @branchedCallbacks = []

  started: (callback) ->
    callback c for c in @startedChoices
    @startedCallbacks.push callback
    return

  aborted: (callback) ->
    callback c for c in @abortedChoices
    @abortedCallbacks.push callback
    return

  branched: (callback) ->
    callback c for c in @branchedChoices
    @branchedCallbacks.push callback
    return

  onAbort: (choice, reason, value, branched = false) =>
    log.tree "#{@name or @id} Non-collection #{choice} aborted with reason '%s'", reason
    value = new Error reason unless value
    aborted =
      choice: choice
      reason: reason
      value: value
      branched: branched
    @abortedChoices.push aborted
    c aborted for c in @abortedCallbacks

  onSubtree: (choice, name, continuation, callback) =>
    tree = new BehaviorTree name, @options
    log.tree "#{@name or @id} new #{if continuation then 'continuation' else 'subtree'} #{tree.name or tree.id} from #{choice}"
    t = new Thenable tree
    choice.subtrees = [] unless choice.subtrees
    choice.subtrees.push tree

    node = tree.nodes['root']
    node.parentSource = choice
    subChoice = new @options.Choice null, 'root', name
    subChoice.treeId = tree.id
    node.choices[''] = subChoice
    node.choices[''].onSubtree = tree.onSubtree
    node.choices[''].onAbort = tree.onAbort
    node.choices[''].onBranch = tree.onBranch
    node.choices[''].parentSource = choice
    node.choices[''].continuation = continuation

    callback t, tree if callback
    t

  onBranch: (orig, branch, callback, silent) =>
    log.tree "#{@name or @id} Branch #{branch} from #{orig}"
    log.branch "#{@name or @id} Branch #{branch} from #{orig}"
    if orig.id is 'root'
      throw new Error 'Cannot branch the root node'
    originalNode = @nodes[orig.id]
    unless originalNode
      throw new Error "Source node #{orig.id} not found"
    id = @registerNode originalNode.promiseSource, branch.name, originalNode.type, callback, false, branch.source.id
    sourcePath = if orig.source then orig.source.toString() else ''
    branch.treeId = @id
    @nodes[id].choices[sourcePath] = branch
    @nodes[id].destinations = originalNode.destinations.slice 0
    originalNode.branches = [] unless originalNode.branches
    originalNode.branches.push @nodes[id]

    # Let parent know of new branch
    @startedChoices.push branch
    c branch for c in @startedCallbacks
    @branchedChoices.push branch
    c branch for c in @branchedCallbacks
    orig.abort "Branched off to #{branch}", null, true

    sourcePath = orig.source.source?.toString()
    sourcePath = '' if originalNode.promiseSource is 'root'
    #@resolve orig.source.id, sourcePath

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

  registerNode: (source, name, type, callback, autoresolve = true, onlySource = null) ->
    unless callback
      type = name
      callback = type
      name = null

    id = @createId name or type

    unless @nodes[source]
      throw new Error "Unknown source #{source} for choice #{id}"

    if @nodes[id]
      throw new Error "Node #{id} already exists"

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

    unless onlySource
      @findSources @nodes[id], autoresolve
    else
      @nodes[id].sources.push @nodes[onlySource]
      @nodes[onlySource].destinations.push @nodes[id]

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
      choice.onAbort = @onAbort
      choice.continuation = sourceChoice.continuation
      node.choices[sourcePath] = choice
    choice = node.choices[sourcePath]
    localPath = node.choices[sourcePath].toString()
    if choice.state in [State.ABORTED, State.RUNNING]
      log.tree "#{@name or @id} #{choice} was already executed, ignoring"
      return
    choice.state = State.RUNNING
    try
      val = node.callback choice, data
      if val and typeof val.then is 'function' and typeof val.else is 'function'
        log.values "#{@name or @id} #{choice} returned subtree #{val.tree.name or val.tree.id} #{val.id}"
        onResult = (state, value) =>
          return unless state.isComplete()
          if state.countFulfilled() is 1
            f = state.getBranches()[0][0]
            log.values "#{@name or @id} #{choice} resulted via subtree in #{typeof f.value} %s", f.value
            choice.registerSubleaf f.choice, true, true
            choice.set 'data', f.value if isActive choice
            choice.state = State.FULFILLED if isActive choice
            @resolve node.id, sourcePath
            return
          if state.countFulfilled() > 1
            branches = state.getBranches()
            branches.forEach (f, i) =>
              f.forEach (fulfilled) =>
                choice.branch "#{choice.id}_#{i}", (bnode) =>
                  bnode.addPath choice.id
                  log.values "#{@name or @id} #{choice} resulted via branch #{bnode} in #{typeof fulfilled.value} %s", fulfilled.value
                  bnode.registerSubleaf fulfilled.choice, true, true
                  fulfilled.value
                , true
            @executeBranches choice.id, "thenable subtree #{branches.length}"
            return
          if state.countRejected()
            [rejected] = state.getBranches state.rejected
            for f in rejected
              choice.registerSubleaf f.choice, false
            choice.set 'data', rejected[0].value if isActive choice
            choice.state = State.REJECTED if isActive choice
            @resolve node.id, sourcePath
            return
          aborted = state.getAborted()
          choice.set 'data', aborted[aborted.length - 1] if isActive choice
          choice.state = State.REJECTED if isActive choice
          @resolve node.id, sourcePath

        state = new SubtreeResults 1, choice
        state.registerTree 0, val.tree, onResult
        # Thenable returned, make subtree
        val.then (c, r) ->
          state.handleResult state.fulfilled, 0, c, r, onResult
          return state
        val.else (c, e) ->
          state.handleResult state.rejected, 0, c, e, onResult
          return state
        return state
      # Straight-up value returned
      if choice.state is State.ABORTED
        @executeBranches node.id, 'direct'
        return
      return if choice.state is State.ABORTED
      return if typeof val?.isComplete is 'function' and not val.isComplete()
      unless typeof val?.isComplete is 'function'
        log.values "#{@name or @id} #{choice} resulted directly in #{typeof val} %s", val
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

  resolve: (id, sourcePath = '', fromBranch = false) ->
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
    choice.onAbort = @onAbort
    choice.parentSource = @nodes['root'].parentSource
    if typeof data is 'object' and toString.call(data) isnt '[object Array]'
      for key, val of data
        choice.set key, val
    choice.set 'data', data if isActive choice
    choice.state = state
    node.choices[''] = choice
    @startedChoices.push choice
    c choice for c in @startedCallbacks
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

    handleSourceBranches = (source) =>
      return unless source.branches and source.branches.length
      for branch in source.branches
        choice.sources.push branch if choice.sources.indexOf(branch) is -1
        branch.destinations.push choice if branch.destinations.indexOf(choice) is -1
        for path, c of branch.choices
          @resolve branch.id, path if autoresolve
        handleSourceBranches branch

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

      handleSourceBranches source

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

  executeBranches: (id, from) ->
    return unless @nodes[id]

    for p, c of @nodes[id].choices
      sourcePath = c.source.source?.toString() or ''
      @resolve c.source.id, sourcePath

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
