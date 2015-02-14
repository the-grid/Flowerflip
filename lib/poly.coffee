Root = require './Root'

exports.solvePage = (filter, page, options, callback) ->
  root = Root()
  root.deliver page
  filter root
  .finally (c, val) ->
    if typeof val is 'object'
      keys = Object.keys val
      if keys.length > 0
        result = val[keys[0]].value
    else
      result = val
    return callback result if result instanceof Error
    return callback null, [ result ]

# Set up entrypoint expected by Poly solver
exports.register = (filter) ->
  polySolvePage = (page, options, callback) ->
    exports.solvePage filter, page, options, callback
  window.polySolvePage = polySolvePage if window?



