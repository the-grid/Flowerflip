getSections = (n) ->
  sections = n.get 'system:layout:sections'
  sections

module.exports = (c, data) ->
  tree = c.continue 'sections'
  tree.deliver data
  .contest getSections, (n, results) ->
    results[0]
  , (n, chosen) ->
    return false if n.availableItems().length
    true
  .then (n, ds) ->
    "<section class=\"#{c.get('system:color:id')} #{c.get('system:layout:id')}\">#{ds.join('\n')}</section>"
