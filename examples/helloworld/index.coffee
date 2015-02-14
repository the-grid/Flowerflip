
module.exports = (t) ->
  t.all require './systems/all'
  .then require './sections/tree'

require('../../lib/poly').register module.exports
