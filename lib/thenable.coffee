{State} = require './state'
BehaviorTree = require './BehaviorTree'

class Thenable
  constructor: (@tree, @options = {}) ->
    @tree = new BehaviorTree unless @tree
    @id = 'root'

  all: (name, tasks) ->
    if typeof name isnt 'string'
      tasks = name
      name = null

    @then name, (path, data) ->
      fulfilled = []
      rejected = []
      composite = new Thenable null,
        name: name
      tasks.forEach (t, i) ->
        val = t data
        if val and typeof val.then is 'function' and typeof val.else is 'function'
          val.then (p, d) ->
            fulfilled.push d
            return unless fulfilled.length is tasks.length
            composite.deliver fulfilled
            d
          val.else (p, e) ->
            rejected.push e
            composite.reject e if composite.state is State.PENDING
            e
          return
      composite

  some: (name, tasks) ->
    if typeof name isnt 'string'
      tasks = name
      name = null

    composite = new Thenable @tree
    composite.type = 'some'
    composite.id = @tree.createId(name or 'some')
    composite.parent = @parent

    fulfilled = []
    rejected = []
    tasks.forEach (t, i) =>
      tName = t.name or "some#{i}"
      tId = @tree.createId tName
      onFulfilled = (path, data) =>
        @tree.registerDecision @parent.id, tId,
          condition: 'then'
          name: t.name
        @tree.registerDecision tId, composite.id,
          condition: 'some'
        @tree.removeDecision @parent.id, composite.id
        @tree.followChoice @parent.id, tId
        val = t data
        if val and typeof val.then is 'function' and typeof val.else is 'function'
          val.then (p, d) =>
            fulfilled.push d
            @tree.followChoice tId, composite.id, d
            return unless fulfilled.length + rejected.length is tasks.length
            composite.deliver fulfilled
            d
          val.else (p, e) =>
            rejected.push e
            @tree.rejectChoice tId, composite.id, e
            return unless fulfilled.length + rejected.length is tasks.length
            if rejected.length is tasks.length
              composite.reject e if composite.state is State.PENDING
            else
              composite.deliver fulfilled
            e
        val
      @async =>
        @subscribers.push
          name: name
          fulfilled: onFulfilled
        do @resolve

    composite

  then: (name, onFulfilled) ->
    if typeof name is 'function'
      onFulfilled = name
      name = null

    id = @tree.registerNode @id, name, 'then', onFulfilled
    promise = new Thenable @tree
    promise.id = id
    @tree.resolve @id
    promise

  else: (name, onRejected) ->
    if typeof name is 'function'
      onRejected = name
      name = null

    id = @tree.registerNode @id, name, 'else', onRejected
    promise = new Thenable @tree
    promise.id = id
    @tree.resolve @id
    promise

  always: (name, onAlways) ->
    if typeof name is 'function'
      onAlways = name
      name = null

    id = @tree.registerNode @id, name, 'always', onAlways
    promise = new Thenable @tree
    promise.id = id
    @tree.resolve @id
    promise

  changeState: ->

  deliver: (value) ->
    @changeState State.FULFILLED, value
    if @id is 'root'
      @tree.execute value
    else
      @tree.resolve @id
    @

  reject: (value) ->
    @changeState State.REJECTED, value
    if @id is 'root'
      @tree.execute value
    else
      @tree.resolve @id
    @

  resolve: ->
    return if @state is State.PENDING

    while @subscribers.length
      sub = @subscribers.shift()
      parent = @parent?.id or 'root'
      funcName = if @state is State.FULFILLED then 'fulfilled' else 'rejected'
      funcName = 'always' if sub.always
      func = sub[funcName]

      unless typeof func is 'function'
        if @id and @parent?.tree is @tree
          @tree.ignoreChoice parent, @id,
            name: sub.name
        sub.promise.changeState @state, @value, @parent if sub.promise
        continue

      try
        subPath = @path.slice(0)
        subPath.push sub.name or funcName
        val = func subPath, @value
        if val and typeof val.then is 'function' and typeof val.else is 'function'
          # Promise returned
          val.then (path, ret) =>
            @async =>
              if @id and @parent?.tree is @tree
                @tree.followChoice parent, @id, ret,
                  name: sub.name
              sub.promise.changeState State.FULFILLED, ret if sub.promise
            ret
          val.else (path, e) =>
            if @id and @parent?.tree is @tree
              @tree.rejectChoice parent, @id
                name: sub.name
            sub.promise.changeState State.REJECTED, e, @parent if sub.promise
            e
          continue
        # Straight-up value returned
        if @id and @parent?.tree is @tree
          @tree.followChoice parent, @id, val,
            name: sub.name
        sub.promise.changeState State.FULFILLED, val if sub.promise
      catch e
        if @id and @parent?.tree is @tree
          @tree.rejectChoice parent, @id, val,
            name: sub.name
        sub.promise.changeState State.REJECTED, e, @parent if sub.promise

  async: (fn) ->
    process.nextTick fn

  toDOT: -> @tree.toDOT()

module.exports = Thenable
