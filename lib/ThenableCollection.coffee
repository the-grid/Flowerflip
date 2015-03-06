{State} = require './state'
SubtreeResults = require './SubtreeResults'
debug = require 'debug'
log =
  tree: debug 'tree'
  errors: debug 'errors'

exports.run = (tasks, composite, choice, data, onResult) ->
  if typeof tasks is 'function'
    tasks = tasks choice, data

  choice.parentOnBranch = (tree, orig, branch, callback) ->
    unless orig.state is State.ABORTED
      orig.abort "Branched off to #{branch}", null, true
    state.branches.push branch

  composite.tree.onAbort = (rChoice, reason, value, branched) ->
    log.tree "#{choice} task #{rChoice} aborted with %s", reason unless branched
    value = new Error reason unless value
    state.aborted.push
      branched: branched
      choice: rChoice
      reason: reason
      value: value
    onResult state, value unless branched
  composite.tree.directOnAbort = false
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
          choice.registerTentativeSubleaf p
          state.handleResult state.fulfilled, i, p, d, onResult
        val.else (p, e) ->
          log.errors "#{choice} task #{i} #{p} resulted in %s", e.message
          return if state.finished
          p.continuation = val.tree.getRootChoice().continuation
          state.handleResult state.rejected, i, p, e, onResult
        return
      state.handleResult state.fulfilled, i, null, val, onResult
    catch e
      log.errors "#{choice} task #{i} resulted in %s", e.message
      state.handleResult state.rejected, i, null, e, onResult

exports.deliverBranches = (state, originalChoice, choice, composite) ->
  branches = state.getBranches()
  if branches.length is 0
    composite.reject new Error "No results for '#{originalChoice} #{choice}'"
    return
  if branches.length is 1
    results = []
    for selected, i in branches[0]
      continue unless selected
      choice.registerSubleaf selected.choice, true
      results[i] = selected.value
    originalChoice.registerSubleaf choice, true
    composite.deliver results
    return
  originalChoice.state = State.ABORTED
  branches.forEach (b, i) ->
    choice.branch "#{choice.id}_#{i}", (bnode) ->
      results = []
      for selected, idx in b
        continue unless selected
        bnode.registerSubleaf selected.choice, true
        results[idx] = selected.value
      originalChoice.branch "#{originalChoice.id}_#{i}", (bbnode) ->
        bbnode.registerSubleaf bnode, true
        results
      return
    return
  return
