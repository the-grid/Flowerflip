Tree = require './tree'

State =
  PENDING: 0
  FULFILLED: 1
  REJECTED: 2

class Thenable
  constructor: (@decisionTree) ->
    @state = State.PENDING
    @value = null
    @subscribers = []
    @decisionTree = new Tree unless @decisionTree
    @path = @decisionTree.namedPath

  tree: (name, callback) ->
    if typeof name is 'function'
      callback = name
      name = null

    @decisionTree.getRoot().label = name if name

    try
      val = callback()
      if val and typeof val.then is 'function' and typeof val.else is 'function'
        val.then (ret) =>
          @deliver ret
        val.else (e) =>
          @reject e
        return
      @deliver val
    catch e
      @reject e
    @

  branch: (name, callback) ->

  then: (name, onFulfilled) ->
    if typeof name is 'function'
      onFulfilled = name
      name = null

    nodeName = name or 'then'
    @decisionTree.addChoice nodeName,
      label: nodeName

    promise = new Thenable @decisionTree

    @async =>
      @subscribers.push
        name: name
        promise: promise
        fulfilled: onFulfilled
      do @resolve
    promise

  else: (name, onRejected) ->
    if typeof name is 'function'
      onRejected = name
      name = null
    promise = new Thenable @decisionTree
    @subscribers.push
      name: name
      promise: promise
      rejected: onRejected

    nodeName = name or 'else'
    @decisionTree.addChoice nodeName,
      label: nodeName

    do @resolve
    promise

  always: (name, onAlways) ->
    if typeof name is 'function'
      onAlways = name
      name = null
    promise = new Thenable @decisionTree
    @subscribers.push
      name: name
      promise: promise
      always: onAlways

    nodeName = name or 'always'
    @decisionTree.addChoice nodeName,
      label: nodeName

    do @resolve
    promise

  changeState: (state, value) ->
    if @state is state
      throw new Error "Cannot transition to same state"

    if @state is State.FULFILLED and state is State.REJECTED
      throw new Error "Cannot reject an already fulfilled promise"

    if state is State.FULFILLED and not value
      throw new Error "Fulfilling promises requires a value"

    if state is State.REJECTED and not value
      throw new Error "Rejecting promises requires a value"

    @state = state
    @value = value
    do @resolve
    @state

  deliver: (value) ->
    @changeState State.FULFILLED, value

  reject: (value) ->
    @changeState State.REJECTED, value

  resolve: ->
    return if @state is State.PENDING

    while @subscribers.length
      sub = @subscribers.shift()
      funcName = if @state is State.FULFILLED then 'fulfilled' else 'rejected'
      funcName = 'always' if sub.always
      func = sub[funcName]

      unless typeof func is 'function'
        @decisionTree.ignoreChoice sub.name or funcName
        sub.promise.changeState @state, @value
        continue

      try
        subPath = @path.slice(0)
        subPath.push sub.name or funcName
        val = func subPath, @value
        if val and typeof val.then is 'function' and typeof val.else is 'function'
          # Promise returned
          val.then (ret) ->
            sub.promise.changeState State.FULFILLED, ret
            @decisionTree.followChoice sub.name or funcName
          val.else (e) ->
            sub.promise.changeState State.REJECTED, e
            @decisionTree.rejectChoice sub.name or funcName
          continue
        # Straight-up value returned
        @decisionTree.followChoice sub.name or funcName
        sub.promise.changeState State.FULFILLED, val
      catch e
        @decisionTree.rejectChoice sub.name or funcName
        sub.promise.changeState State.REJECTED, e

  async: (fn) ->
    process.nextTick fn

  toDOT: -> @decisionTree.toDOT()

module.exports = Thenable
