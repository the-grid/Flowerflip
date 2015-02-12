getSections = (n) ->
  sections = n.get 'sections'
  sections

module.exports = (c, data) ->
  tries = 0
  tree = c.continue 'sections'
  tree.deliver data
  .contest getSections, (n, results) ->
    p = n.namedPath()
    results[0]
  , (n, chosen) ->
    tries++
    return true if tries > 3
    return false if n.availableItems().length
    true
  .then (n, ds) ->
    "<section class=\"#{c.get('color')} #{c.get('layout')}\">#{ds.map((d) -> d.value[0]).join('\n')}</section>"
