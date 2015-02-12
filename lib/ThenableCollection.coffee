{State} = require './state'

module.exports = (tasks, composite, choice, data, onResult) ->
  if typeof tasks is 'function'
    tasks = tasks choice, data

  state =
    finished: false
    branches: []
    aborted: []
    fulfilled: []
    rejected: []
    choices: []
    countFulfilled: ->
      full = 0
      for f in state.fulfilled
        if f instanceof Array
          full += f.length
          continue
        full++
      full
    countRejected: ->
      rej = 0
      for r in state.rejected
        if r instanceof Array
          rej += r.length
          continue
        rej++
      rej
    isComplete: ->
      todo = tasks.length + state.branches.length = state.aborted.length
      done = state.countFulfilled() + state.countRejected()
      done >= todo

  composite.tree.parentOnBranch = (tree, orig, branch, callback) ->
    unless orig.state is State.ABORTED
      state.aborted.push orig
      orig.abort "Branched off to #{branch}"
    state.branches.push branch

  return onFulfilled state unless tasks.length
  tasks.forEach (t, i) ->
    return if state.finished
    try
      val = t choice, data
      if val and typeof val.then is 'function' and typeof val.else is 'function'
        val.then (p, d) ->
          state.choices[i] = if state.choices[i] then [state.choices[i], p] else p
          state.fulfilled[i] = if state.fulfilled[i] then [state.fulfilled[i], d] else d
          p.continuation = val.tree.continuation
          choice.registerSubleaf p, true
          onResult state, d
        val.else (p, e) ->
          state.choices[i] = if state.choices[i] then [state.choices[i], p] else p
          state.rejected[i] = if state.rejected[i] then [state.rejected[i], e] else e
          p.continuation = val.tree.continuation
          choice.registerSubleaf p, false
          onResult state, e
        return
      state.fulfilled[i] = if state.fulfilled[i] then [state.fulfilled[i], val] else val
      onResult state, val
    catch e
      state.rejected[i] = if state.rejected[i] then [state.rejected[i], e] else e
      onResult state, e
