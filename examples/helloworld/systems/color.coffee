module.exports = (choice, data) ->
  tree = choice.continue 'color'
  tree.deliver data
  .then 'user', (c, d) ->
    c.expect(d.config.color).to.be.a 'string'
    c.addPath d.config.color
    d.config.color
  .else 'derived', (c, d) ->
    color = 'blue'
    c.addPath color
    color
  .then (c, d) ->
    choice.set 'system:color:id', d
    data
