{State, ensureActive} = require './state'

class Choice
  constructor: (source, id, @name) ->
    unless id
      id = source
      source = null
    unless id
      throw new Exception 'Choice ID required'

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
      blocksEaten: []
      paths: []

  namedPath: ->
    path = if @source then @source.namedPath() else []
    if @state is State.FULFILLED
      path.push @name if @name
      path = path.concat @attributes.paths
    path

  addPath: (p) ->
    unless typeof p is 'string'
      throw new Error 'Paths must be strings'
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
    unless typeof @onSubtree is 'function'
      throw new Error 'Cannot continue tree without external onSubtree'
    @onSubtree @, name, true, callback

  branch: (name, callback = ->) ->
    unless typeof @onBranch is 'function'
      throw new Error 'Cannot branch without external onBranch'
    id = name.replace /-/g, '_'
    branch = new Choice @source, id, name
    branch.state = State.PENDING
    branch.onBranch = @onBranch
    branch.parentOnBranch = @parentOnBranch
    clone = @toJSON()
    for key, val of clone
      continue if key in ['path', 'id']
      branch.attributes[key] = val

    @state = State.ABORTED

    @onBranch @, branch, callback

    branch

  registerSubleaf: (leaf, fulfilled) ->
    @subLeaves = [] unless @subLeaves
    @subLeaves.push leaf
    return unless fulfilled and leaf.continuation
    items = @availableItems()
    leafItems = leaf.availableItems()

    paths = leaf.namedPath()
    @addPath p for p in paths

    for i in items
      continue unless leafItems.indexOf(i) is -1
      @eatItem i

  acceptedSubleaves: ->
    return [] unless @subLeaves.length
    @subLeaves.filter (l) -> l.state is State.FULFILLED and l.continuation

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
    @attributes[name] = value

  getItem: (callback) ->
    ensureActive @
    items = @availableItems()
    return null unless items.length

    unless typeof callback is 'function'
      return items[0]

    for item in items
      try
        ret = callback item
        return item if ret
      catch e
        continue
    null

  eatItem: (item, node = null) ->
    ensureActive @
    throw new Error 'No item provided' unless item
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
    else
      items = @attributes.items

    # Filter out the ones we've eaten
    items.filter (i) =>
      @attributes.itemsEaten.indexOf(i) is -1

  isSubtypeOf: (type, checkType) ->
    if typeof type is 'object'
      type = type.type

    # TODO: Parse from The Grid JSON Schema
    return true if checkType is 'block'
    return true if type is checkType
    if checkType is 'textual'
      return true if type in ['text', 'code']
      return @isSubtypeOf type, 'headline'
    if checkType is 'media'
      return type in ['image', 'video', 'audio', 'article', 'location', 'quote']
    if checkType is 'headline'
      return type in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
    if checkType is 'data'
      return type in ['list', 'table']
    false

  getBlock: (item, callback) ->
    ensureActive @
    return null unless item.content?.length
    blocks = @availableBlocks item
    return null unless blocks.length

    unless typeof callback is 'function'
      return blocks[0]

    for block in blocks
      try
        ret = callback block
        return block if ret
      catch e
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

  toString: -> @path.join '-'

module.exports = Choice
