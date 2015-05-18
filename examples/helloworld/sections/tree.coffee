compare = (a, b) ->
  if a.total > b.total
    return -1
  if a.total < b.total
    return 1
  return 0

getSections = (n) ->
  sections = n.get 'system:layout:sections'
  sections

module.exports = (c, data) ->
  tree = c.continue 'sections'
  tree.deliver data
  .contest getSections, (n, results, chosenSolutions) ->
    before = chosenSolutions.map (c) -> c.choice.toSong()
    for r in results
      song = before.concat [r.choice.toSong()]
      score = 0
      for p in song[song.length - 1].path
        continue unless before.length
        if before[before.length - 1].path.indexOf(p) is -1
          score++
      r.total = score
    results.sort compare
    results[0]
  , (n, chosen) ->
    return false if n.availableItems().length
    true
  .then (n, ds) ->
    "<section class=\"#{c.get('system:color:id')} #{c.get('system:layout:id')}\">#{ds.join('\n')}</section>"
