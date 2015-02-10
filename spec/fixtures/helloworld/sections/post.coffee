titlesComponent = (type, choice, item) ->
  console.log 'titles '+choice, item
  t = choice.tree 'title'
  t.deliver item
  .then (c, d) ->
    block = choice.getBlock item, (b) ->
      b.type is type
    choice.eatBlock block
    block

textComponent = (choice, item) ->
  console.log 'text '+choice, item
  t = choice.tree 'text'
  t.deliver item
  .then (c, d) ->
    block = choice.getBlock item, (b) ->
      b.type is 'text'
    choice.eatBlock block
    block

module.exports = (choice, data) ->
  t = choice.tree 'post'
  t.deliver data
  .then (c, d) ->
    item = c.getItem (i) ->
      i.content.length > 1
    throw new Error 'No item' unless item
    c.set 'item', item
    item
  .some [
    titlesComponent.bind @, 'h1'
    textComponent
  ]
  .then (c, res) ->
    choice.eatItem c.get 'item'
  .else (c, e) ->
    console.log e.stack
    throw e
