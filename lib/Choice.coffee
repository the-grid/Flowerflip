class Choice
  constructor: (source, id) ->
    unless id
      id = source
      source = null
    unless id
      throw new Exception 'Choice ID required'


    @id = id
    @source = source

    @path = if @source then @source.path.slice(0) else []
    @path.push id

    @attributes =
      items: []
      itemsEaten: []
      blocksEaten: []

  getItem: (callback) ->
    items = @availableItems()
    return null unless items.length
    for item in items
      try
        callback item
        return item
      catch e
        continue
    null

  eatItem: (item, node = null) ->
    @attributes.itemsEaten.push item

  availableItems: ->
    # Get original list of nodes
    if @source
      items = @source.availableItems()
      items = items.concat @attributes.items if @attributes.items.length
    else
      items = @attributes.items

    # Filter out the ones we've eaten
    items.filter (i) =>
      @attributes.itemsEaten.indexOf(i) is -1

  getBlock: (item, callback) ->
    blocks = @availableBlocks item
    return null unless blocks.length
    for block in blocks
      try
        callback block
        return block
      catch e
        continue
    null

  eatBlock: (block, node = null) ->
    @attributes.blocksEaten.push block
    # TODO: Auto-mark item as eaten when all necessary blocks are consumed

  availableBlocks: (item) ->
    blocks = if @source then @source.availableBlocks(item) else item.content
    blocks.filter (b) =>
      @attributes.blocksEaten.indexOf(b) is -1

  toJSON: ->
    base =
      id: @id
      path: @path

    for key, val of @attributes
      if typeof val.slice is 'function'
        base[key] = val.slice 0
        continue
      base[key] = val

    base

module.exports = Choice
