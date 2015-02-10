getSections = (n) ->
  sections = n.get 'sections'
  sections

module.exports = (c, data) ->
  tree = c.tree 'sections'
  tree.deliver data
  .contest getSections, (results) ->
    c.eatItem results[0].value
  , (n) ->
    return false if n.availableItems().length
    true
  .then (n, ds) ->
    "<section>#{ds.join('\n')}</section>"
