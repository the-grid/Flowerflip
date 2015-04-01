titlesComponent = (type, choice, item) ->
  t = choice.tree 'title'
  t.deliver item
  .then (c, d) ->
    block = choice.getBlock item, (b) ->
      c.expect(b.type).to.equal type
    c.expect(block).to.be.an 'object'
    choice.eatBlock block
    block
  .then (c, b) ->
    "<#{type}>#{b.text}</#{type}>"

textComponent = (choice, item) ->
  t = choice.tree 'text'
  t.deliver item
  .then (c, d) ->
    block = choice.getBlock item, (b) ->
      c.expect(b.type).to.equal 'text'
    c.expect(block).to.be.an 'object'
    choice.eatBlock block
    block
  .then (c, b) ->
    "<p>#{b.text}</p>"

blockComponent = (choice, item) ->
  t = choice.tree 'text'
  t.deliver item
  .then (c, d) ->
    block = choice.getBlock item, (b) ->
      ch.expect(b.html).to.be.a 'string'
      b.type not in ['text', 'h1']
    c.expect(block).to.be.an 'object'
    choice.eatBlock block
    block
  .then (c, b) ->
    b.html

module.exports = (choice, data) ->
  t = choice.tree 'post'
  t.deliver data
  .then (c, d) ->
    item = c.getItem (i) ->
      i.content.length is 1
    c.expect(item).to.be.an 'object'
    c.set 'item', item
    c.branch 'left', (b) ->
      b.set 'variant', 'left'
      item
    c.branch 'right', (b) ->
      b.set 'variant', 'right'
      item
  .then (c, d) ->
    c.branch 'light', (b) ->
      d
    c.branch 'dark', (b) ->
      d
  .else (d, e) ->
    d.get 'item'
  .some [
    titlesComponent.bind @, 'h1'
    textComponent
    blockComponent
  ]
  .then (c, res) ->
    # Mark item as eaten upstream
    choice.eatItem c.get 'item'
    variant = c.get 'variant'
    "<article class=\"post #{variant}\">#{res.join('\n')}</article>\n"
