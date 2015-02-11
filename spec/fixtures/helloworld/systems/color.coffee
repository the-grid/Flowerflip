module.exports = (choice, data) ->
  tree = choice.continue 'color'
  tree.deliver data
  .then 'user', (c, d) ->
    unless d.config.color
      throw new Error 'No color selected'
    d.config.color
  .else 'derived', (c, d) ->
    'blue'
  .then (c, d) ->
    choice.set 'color', d
    data
