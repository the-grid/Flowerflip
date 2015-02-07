class Choice
  constructor: (@source) ->
    @items = []
    @itemsEaten = []
    @blocksEaten = []

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
    @itemsEaten.push item

  availableItems: ->
    # Get original list of nodes
    items = if @source then @source.availableItems() else @items

    # Filter out the ones we've eaten
    items.filter (i) =>
      @itemsEaten.indexOf(i) is -1

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
    @blocksEaten.push block
    # TODO: Auto-mark item as eaten when all necessary blocks are consumed

  availableBlocks: (item) ->
    blocks = if @source then @source.availableBlocks(item) else item.content
    blocks.filter (b) =>
      @blocksEaten.indexOf(b) is -1

module.exports = Choice
