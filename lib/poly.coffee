Root = require './Root'

# @callback = (err, html, details) ->
exports.solvePage = (filter, page, options, callback) ->
  root = Root()
  root.deliver page
  filter root
  .finally (c, val) ->
    try
      return callback val, null, c if val instanceof Error
      return callback null, val, c
    catch e
      return callback e

# Set up entrypoint expected by Poly solver
exports.register = (filter) ->
  polySolvePage = (page, options, callback) ->
    exports.solvePage filter, page, options, callback
  window.polySolvePage = polySolvePage if window?
  exports.polySolvePage = polySolvePage



