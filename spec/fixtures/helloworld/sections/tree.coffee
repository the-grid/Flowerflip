getSections = (n) ->
  sections = n.get 'sections'
  console.log "SECTIONS", sections
  sections

module.exports = (c, data) ->
  console.log c.get 'sections'
  tree = c.tree 'sections'
  tree.deliver data
  .contest getSections, (results) ->
    console.log results
    results[0].value
  .until (n) ->
    return false if n.availableItems().length
  .then (n, ds) ->
    ds
