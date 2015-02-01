State =
  PENDING: 0
  FULFILLED: 1
  REJECTED: 2

class Thenable
  constructor: ->
    @path = []
    @state = State.PENDING
    @value = null
    @subscribers = []

  tree: (name, callback) ->
    if typeof name is 'function'
      callback = name
      name = null

    try
      val = callback()
      if val and typeof val.then is 'function' and typeof val.else is 'function'
        val.then (ret) =>
          @path.push name if name
          @deliver ret
        val.else (e) =>
          @reject e
        return
      @path.push name if name
      @deliver val
    catch e
      @reject e
    @

  branch: (name, callback) ->

  then: (name, onFulfilled) ->
    if typeof name is 'function'
      onFulfilled = name
      name = null
    promise = new Thenable
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
    promise = new Thenable
    @subscribers.push
      name: name
      promise: promise
      rejected: onRejected

    do @resolve
    promise

  always: (name, onAlways) ->
    if typeof name is 'function'
      onAlways = name
      name = null
    promise = new Thenable
    @subscribers.push
      name: name
      promise: promise
      always: onAlways

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
      sub.promise.path = @path
      func = if @state is State.FULFILLED then sub.fulfilled else sub.rejected
      func = sub.always if sub.always

      unless typeof func is 'function'
        sub.promise.changeState @state, @value
        continue

      try
        @path.push sub.name if sub.name
        val = func @path, @value
        if val and typeof val.then is 'function' and typeof val.else is 'function'
          # Promise returned
          val.then (ret) ->
            sub.promise.changeState State.FULFILLED, ret
          val.else (e) ->
            sub.promise.changeState State.REJECTED, e
          continue
        # Straight-up value returned
        sub.promise.changeState State.FULFILLED, val
      catch e
        @path.pop()
        sub.promise.changeState State.REJECTED, e

module.exports = Thenable
