module.exports = (tasks, choice, data, onResult) ->
  state =
    finished: false
    fulfilled: []
    rejected: []
    countFulfilled: ->
      full = state.fulfilled.filter (f) -> typeof f isnt 'undefined'
      full.length
    countRejected: ->
      rej = state.rejected.filter (r) -> typeof r isnt 'undefined'
      rej.length
    isComplete: ->
      state.countFulfilled() + state.countRejected() is tasks.length
  return onFulfilled state unless tasks.length
  tasks.forEach (t, i) ->
    return if state.finished
    try
      val = t choice, data
      if val and typeof val.then is 'function' and typeof val.else is 'function'
        val.then (p, d) ->
          state.fulfilled[i] = d
          onResult state, d
        val.else (p, e) ->
          state.rejected[i] = e
          onResult state, e
        return
      state.fulfilled[i] = val
      onResult state, val
    catch e
      state.rejected[i] = e
      onResult state, e
