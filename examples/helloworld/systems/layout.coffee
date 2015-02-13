layouts =
  simple: [
  ]
  directed: [
    require '../sections/post'
  ]

module.exports = (choice, data) ->
  tree = choice.continue 'layout'
  tree.deliver data
  .then 'user', (c, d) ->
    c.expect(d.config.layout).to.be.a 'string'
    c.expect(layouts[d.config.layout]).to.be.an 'array'
    c.expect(layouts[d.config.layout]).not.to.be.empty
    choice.set 'system:layout:id', d.config.layout
    c.addPath d.config.layout
    layouts[d.config.layout]
  .else 'derived', (c, d) ->
    layout = 'simple'
    c.addPath layout
#    choice.set 'system:layout:id', layout
    layouts[layout]
  .then (c, d) ->
    choice.set 'system:layout:sections', d
    data

