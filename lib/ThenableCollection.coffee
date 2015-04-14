{State} = require './state'
SubtreeResults = require './SubtreeResults'
debug = require 'debug'
chai = require 'chai'
log =
  tree: debug 'tree'
  errors: debug 'errors'
  asserts: debug 'asserts'
  values: debug 'values'

exports.run = (tasks, composite, choice, data, onResult, eatTentatively = true) ->
  if typeof tasks is 'function'
    tasks = tasks choice, data

  state = new SubtreeResults tasks.length, choice
  unless tasks.length
    state.started[0] = []
    state.started[0][''] = true
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
        log.values "#{choice.treeId} #{choice} ##{i} returned subtree #{val.tree.name or val.tree.id} #{val.id}"
        state.registerTree i, val.tree, onResult
        val.then (p, d) ->
          log.values "#{choice} task #{i} #{p} resulted in #{typeof d} %s", d
          choice.registerTentativeSubleaf p if eatTentatively
          state.handleResult state.fulfilled, i, p, d, onResult
          return
        val.else (p, e) ->
          log.errors "#{choice} task #{i} #{p} resulted in %s", e.message
          return if state.finished
          state.handleResult state.rejected, i, p, e, onResult
          return
        return
      return if choice.state is State.ABORTED
      return if typeof val?.isComplete is 'function' and not val.isComplete()
      log.values "#{choice} task #{i} resulted directly in #{typeof val} %s", val
      state.handleResult state.fulfilled, i, null, val, onResult
    catch e
      if e instanceof chai.AssertionError
        log.asserts "#{@name or @id} #{choice} resulted in %s", e.message
      log.errors "#{choice} task #{i} resulted in %s", e.message
      state.handleResult state.rejected, i, null, e, onResult
  return state

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
  branches.forEach (b, i) ->
    choice.branch "#{choice.id}_#{i}", (bnode) ->
      if choice.name and not choice.silent
        bnode.name = choice.name
        bnode.silent = false
      results = []
      for selected, idx in b
        continue unless selected
        bnode.registerSubleaf selected.choice, true
        results[idx] = selected.value
      return results
    , true
    return
  return
