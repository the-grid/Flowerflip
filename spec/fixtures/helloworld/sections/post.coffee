titlesComponent = (type, choice, item) ->
  t = choice.tree 'title'
  t.deliver item
  .then (c, d) ->
    block = choice.getBlock item, (b) ->
      b.type is type
    choice.eatBlock block
    block
  .then (c, b) ->
    "<#{type}>#{b.text}</#{type}>"

textComponent = (choice, item) ->
  t = choice.tree 'text'
  t.deliver item
  .then (c, d) ->
    block = choice.getBlock item, (b) ->
      b.type is 'text'
    choice.eatBlock block
    block
  .then (c, b) ->
    "<p>#{b.text}</p>"
called = 0
module.exports = (choice, data) ->
  t = choice.tree 'post'
  t.deliver data
  .then (c, d) ->
    called++
    item = c.getItem (i) ->
      i.content.length is 1
    throw new Error called + ' No item' unless item
    c.set 'item', item
    item
  .some [
    titlesComponent.bind @, 'h1'
    textComponent
  ]
  .then (c, res) ->
    results = res.filter (r) -> typeof r isnt 'undefined'
    # Mark item as eaten upstream
    choice.eatItem c.get 'item'
    "<article class=\"post\">#{results.join('\n')}</article>\n"
