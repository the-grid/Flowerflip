titlesComponent = (type, choice, item) ->
  t = choice.tree 'title'
  t.deliver item
  .then (c, d) ->
    block = choice.getBlock item, (b) ->
      c.expect b.type, (exp) ->
        exp.to.equal type
    choice.eatBlock block
    block
  .then (c, b) ->
    "<#{type}>#{b.text}</#{type}>"

textComponent = (choice, item) ->
  t = choice.tree 'text'
  t.deliver item
  .then (c, d) ->
    block = choice.getBlock item, (b) ->
      c.expect b.type, (exp) ->
        exp.to.equal 'text'
    choice.eatBlock block
    block
  .then (c, b) ->
    "<p>#{b.text}</p>"

module.exports = (choice, data) ->
  t = choice.tree 'post'
  t.deliver data
  .then (c, d) ->
    item = c.getItem (i) ->
      i.content.length is 1
    c.expect item, (exp) ->
      exp.to.be.an 'object'
    c.set 'item', item
    c.branch 'left', (b) ->
      b.set 'variant', 'right'
      item
    c.branch 'right', (b) ->
      b.set 'variant', 'right'
      item
  .else (d, e) ->
    d.get 'item'
  .some [
    titlesComponent.bind @, 'h1'
    textComponent
  ]
  .then (c, res) ->
    results = res.filter (r) -> typeof r isnt 'undefined'
    # Mark item as eaten upstream
    choice.eatItem c.get 'item'
    variant = c.get 'variant'
    "<article class=\"post #{variant}\">#{results.join('\n')}</article>\n"
