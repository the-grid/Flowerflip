{State, ensureActive} = require './state'
chai = require 'chai'
{isSubtypeOf} = require './schema'

globalValues = {}

debug = require 'debug'
log =
  subleaf: debug 'subleaf'
  asserts: debug 'asserts'
  errors: debug 'errors'

class Choice

  @ensureActive: ensureActive
  @State: State

  isSubtypeOf: isSubtypeOf

  constructor: (source, id, @name) ->
    unless id
      id = source
      source = null
    unless id
      throw new Exception 'Choice ID required'

    @treeId = null
    @id = id
    @source = source
    @parentSource = null
    @subLeaves = []
    @state = 0
    @onBranch = null
    @state = State.PENDING

    @path = if @source then @source.path.slice(0) else []
    @path.push id

    @attributes =
      items: []
      itemsEaten: []
      tentativeItemsEaten: []
      blocksEaten: []
      globalsSet: []
      paths: []

    @continuation = false

  hasSource: (choice) ->
    return true if @ is choice
    return false unless @source
    return true if @source is choice
    @source.hasSource choice

  namedPath: (includeSelf = false) ->
    path = if @source then @source.namedPath() else []
    if @state is State.FULFILLED or includeSelf
      path.push @name if @name and not @silent and @name.substr(0,2) isnt '//'
      path = path.concat @attributes.paths
    path

  addPath: (p) ->
    if p instanceof Array
      unique = p.filter (path) =>
        return false unless @attributes.paths.indexOf(path) is -1
        return false if @name is path
        true
      return unless unique.length
      @addPath path for path in p
      return
    unless typeof p is 'string'
      throw new Error 'Paths must be strings'
    return if p is @name
    @attributes.paths.push p

  fulfilledPath: ->
    return [] if @id is 'root'
    path = if @source then @source.fulfilledPath() else []
    path.push @id if @state is State.FULFILLED
    path

  tree: (name, callback = ->) ->
    unless typeof @onSubtree is 'function'
      throw new Error 'Cannot subtree without external onSubtree'
    @onSubtree @, name, false, callback

  continue: (name, callback = ->) ->
    name = null unless name
    unless typeof @onSubtree is 'function'
      throw new Error 'Cannot continue tree without external onSubtree'
    @onSubtree @, name, true, callback

  branch: (name, callback = null, silent = false) ->
    unless callback
      callback = ->
    if typeof name isnt 'string' and not silent
      throw new Error 'Branches cannot be anonymous'
    unless typeof @onBranch is 'function'
      throw new Error 'Cannot branch without external onBranch'
    @branches = 0 unless @branches
    @branches++
    id = name.replace /-/g, '_' if name
    id = "#{@id}_b#{@branches}" unless name
    branch = @createChoice @source, id, name
    branch.continuation = @continuation
    branch.state = State.PENDING
    branch.onBranch = @onBranch
    branch.onSubtree = @onSubtree
    branch.onAbort = @onAbort
    branch.silent = silent
    branch.branchSource = @
    clone = @toJSON()
    for key, val of clone
      continue if key in ['path', 'id', 'aborted']
      branch.attributes[key] = val

    @onBranch @, branch, callback, silent

    branch

  # Used for testing whether input data matches preconditions
  expect: (value = undefined, throwData = null, message) ->
    args = [].slice.call arguments
    unless args.length
      return chai.expect
    @set 'preconditionFailedData', throwData if throwData
    chai.expect value, message

  # Used for programmer errors, when input data is completely wrong
  error: (message) ->
    throw new Error message

  # Used for aborting the execution of the current tree path
  abort: (reason, value, onBranch = false) ->
    return if @state is State.ABORTED
    @set 'aborted', reason
    @state = State.ABORTED
    return unless @onAbort
    @onAbort @, reason, value, onBranch

  registerSubleaf: (leaf, accepted, consumeWithoutContinuation = true) ->
    log.subleaf "#{@treeId} #{@} register subleaf #{leaf.treeId} #{leaf}, #{accepted} #{leaf.availableItems().length}"
    @attributes.tentativeItemsEaten = []
    @branchSource.attributes.tentativeItemsEaten = [] if @branchSource
    @subLeaves = [] unless @subLeaves
    @subLeaves.push
      choice: leaf
      accepted: accepted
    return unless accepted and (leaf.continuation or consumeWithoutContinuation)

    @addPath leaf.namedPath() if leaf.continuation

    items = @availableItems()
    leafItems = leaf.availableItems()
    for i in items
      continue unless leafItems.indexOf(i) is -1
      @eatItem i, false

  registerTentativeSubleaf: (leaf) ->
    log.subleaf "#{@treeId} #{@} tentative subleaf #{leaf.treeId} #{leaf} #{leaf.availableItems().length}"
    items = @availableItems()
    leafItems = leaf.availableItems()
    for i in items
      continue unless leafItems.indexOf(i) is -1
      @attributes.tentativeItemsEaten.push i

  acceptedSubleaves: ->
    return [] unless @subLeaves.length
    accepted = @subLeaves.filter (l) -> l.accepted and l.choice.state is State.FULFILLED and l.choice.continuation
    accepted.map (a) -> a.choice

  get: (name, followParent = true) ->
    return @attributes[name] if typeof @attributes[name] isnt 'undefined'
    for l in @acceptedSubleaves()
      result = l.get name, false
      return result if result
    if @source
      result = @source.get name, followParent
      return result if result
    if @parentSource and followParent
      result = @parentSource.get name, followParent
      return result if result
    null

  set: (name, value) ->
    ensureActive @
    if name in ['itemsEaten', 'blocksEaten']
      throw new Error "#{name} attribute must be modified via the eat method"
    return if name is 'items' and @parentSource
    @attributes[name] = value

  getGlobal: (name) ->
    globalValues[name]

  setGlobal: (name, value) ->
    ensureActive @
    if globalValues[name]
      throw new Error "Global value '#{name}' is already set"
    globalValues[name] = value

  getItem: (callback) ->
    ensureActive @
    items = @availableItems()
    items = items.slice 0, 1 if @attributes.ordered

    return null unless items.length

    unless typeof callback is 'function'
      return items[0]

    for item in items
      try
        ret = callback item
        return item if ret
      catch e
        log.errors "#{@treeId} #{@} getItem resulted in %s", e.message
        if e instanceof chai.AssertionError
          log.asserts "#{@treeId} #{@} getItem resulted in %s", e.message
        continue
    null

  eatItem: (item, checkActive = true) ->
    ensureActive @ if checkActive
    throw new Error 'No item provided' unless item
    log.subleaf "#{@treeId} #{@} eat #{item.id}" if checkActive
    @attributes.itemsEaten.push item
    item

  availableItems: ->
    # Get original list of nodes
    if @source
      items = @source.availableItems()
      items = items.concat @attributes.items if @attributes.items.length
    else if @parentSource
      items = @parentSource.availableItems()
      items = items.concat @attributes.items if @attributes.items.length
      if @parentSource.attributes.tentativeItemsEaten.length
        for i in @parentSource.attributes.tentativeItemsEaten
          idx = items.indexOf(i)
          continue if idx is -1
          items.splice idx, 1
    else
      items = @attributes.items

    # Filter out the ones we've eaten
    items.filter (i) =>
      @attributes.itemsEaten.indexOf(i) is -1

  getBlock: (item, callback) ->
    ensureActive @
    return null unless item.content?.length
    blocks = @availableBlocks item
    blocks = blocks.slice 0, 1 if @attributes.ordered
    return null unless blocks.length

    unless typeof callback is 'function'
      return blocks[0]

    for block in blocks
      try
        ret = callback block
        return block if ret
      catch e
        log.errors "#{@treeId} #{@} getItem resulted in %s", e.message
        if e instanceof chai.AssertionError
          log.asserts "#{@treeId} #{@} getItem resulted in %s", e.message
        continue
    null

  eatBlock: (block, node = null) ->
    ensureActive @
    unless block
      throw new Error "No block provided"
    @attributes.blocksEaten.push block
    # TODO: Auto-mark item as eaten when all necessary blocks are consumed
    block

  availableBlocks: (item) ->
    if @source
      blocks = @source.availableBlocks item
    else if @parentSource
      blocks = @parentSource.availableBlocks item
    else
      blocks = item.content
    blocks.filter (b) =>
      @attributes.blocksEaten.indexOf(b) is -1

  createChoice: (source, id, name) ->
    # Override in subclasses
    c = new Choice source, id, name
    c.continuation = @continuation
    c

  toJSON: ->
    base =
      id: @id
      path: @path.slice 0

    for key, val of @attributes
      if typeof val.slice is 'function'
        base[key] = val.slice 0
        continue
      base[key] = val

    base

  toSong: ->
    @subLeaves = [] unless @subLeaves
    accepted = @subLeaves.filter (l) -> l.accepted and l.choice.state is State.FULFILLED
    song =
      path: @namedPath()
      children: accepted.map (a) -> a.choice.toSong()
    song

  toString: -> @path.join '-'

module.exports = Choice
module.exports.reset = ->
  globalValues = {}
