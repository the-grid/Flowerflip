{State} = require './state'
SubtreeResults = require './SubtreeResults'

module.exports = (tasks, composite, choice, data, onResult) ->
  if typeof tasks is 'function'
    tasks = tasks choice, data

  composite.tree.parentOnBranch = (tree, orig, branch, callback) ->
    unless orig.state is State.ABORTED
      orig.abort "Branched off to #{branch}", null, true
    state.branches.push branch

  composite.tree.onAbort = (rChoice, reason, value, branched) ->
    value = new Error reason unless value
    state.aborted.push
      branched: branched
      choice: rChoice
      reason: reason
      value: value
    onResult state, value unless branched
  choice.onAbort = composite.tree.onAbort

  state = new SubtreeResults tasks.length
  unless tasks.length
    state.handleResult state.rejected, 0, null, new Error("No tasks provided"), onResult
    return

  tasks.forEach (t, i) ->
    return if state.finished
    unless typeof t is 'function'
      e = new Error "Task #{i} of #{choice} is not a function"
      state.handleResult state.rejected, i, null, e, onResult
      return

    try
      val = t choice, data
      if val and typeof val.then is 'function' and typeof val.else is 'function'
        val.then (p, d) ->
          p.continuation = val.tree.getRootChoice().continuation
          choice.registerSubleaf p, true
          state.handleResult state.fulfilled, i, p, d, onResult
        val.else (p, e) ->
          p.continuation = val.tree.getRootChoice().continuation
          choice.registerSubleaf p, false
          state.handleResult state.rejected, i, p, e, onResult
        return
      state.handleResult state.fulfilled, i, null, val, onResult
    catch e
      state.handleResult state.rejected, i, null, e, onResult
