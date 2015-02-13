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
    getFulfilled: -> getResults state.fulfilled
    getRejected: -> getResults state.rejected
    countFulfilled: ->
      full = 0
      for f in state.fulfilled
        continue unless f
        full += Object.keys(f).length
      full
    countRejected: ->
      rej = 0
      for r in state.rejected
        continue unless r
        rej += Object.keys(r).length
      rej
    countAborted: ->
      aborted = state.aborted.filter (a) -> not a.branched
      aborted.length
    isComplete: ->
      todo = tasks.length + state.branches.length - state.aborted.length
      done = state.countFulfilled() + state.countRejected()
      done >= todo

  composite.tree.parentOnBranch = (tree, orig, branch, callback) ->
    unless orig.state is State.ABORTED
      orig.abort "Branched off to #{branch}", true
    state.branches.push branch

  composite.tree.onAbort = (rChoice, reason, branched) ->
    error = new Error reason
    state.aborted.push
      branched: branched
      choice: rChoice
      reason: reason
      error: error
    onResult state, error unless branched

  handleResult = (collection, idx, rChoice, value) ->
    path = if rChoice then rChoice.toString() else ''
    collection[idx] = {} unless collection[idx]
    collection[idx][path] =
      choice: rChoice
      value: value
    onResult state, value

  getResults = (collection) ->
    collection.map (f, i) ->
      return unless f
      keys = Object.keys f
      if keys.length is 1
        return collection[i][keys[0]].value
      keys.map (k) -> collection[i][k].value

  unless tasks.length
    handleResult state.rejected, 0, null, new Error "No tasks provided"
    return

  tasks.forEach (t, i) ->
    return if state.finished
    unless typeof t is 'function'
      e = new Error "Task #{i} of #{choice} is not a function"
      handleResult state.rejected, i, null, e
      return

    try
      val = t choice, data
      if val and typeof val.then is 'function' and typeof val.else is 'function'
        val.then (p, d) ->
          p.continuation = val.tree.getRootChoice().continuation
          choice.registerSubleaf p, true
          handleResult state.fulfilled, i, p, d
        val.else (p, e) ->
          p.continuation = val.tree.getRootChoice().continuation
          choice.registerSubleaf p, false
          handleResult state.rejected, i, p, e
        return
      handleResult state.fulfilled, i, null, val
    catch e
      handleResult state.rejected, i, null, e
