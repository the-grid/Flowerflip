module.exports = (t) ->
  t.all require './systems/all'
  .then require './sections/tree'
