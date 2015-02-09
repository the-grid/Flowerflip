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

    callback = (choice, data) ->
      composite = new Thenable
      composite.tree.id = 'COMPOSITE-ALL'
      fulfilled = []
      rejected = []
      tasks.forEach (t, i) ->
        return if rejected.length
        process.nextTick ->
          try
            val = t data
            if val and typeof val.then is 'function' and typeof val.else is 'function'
              val.then (p, d) ->
                fulfilled.push d
                return null unless fulfilled.length is tasks.length
                composite.deliver fulfilled
                null
              val.else (p, e) ->
                rejected.push e
                composite.reject e unless rejected.length > 1
                e
              return
            fulfilled.push val
            composite.deliver fulfilled if fulfilled.length is tasks.length
          catch e
            rejected.push e
            composite.reject e unless rejected.length > 1
      composite
    id = @tree.registerNode @id, name, 'all', callback
    promise = new Thenable @tree
    promise.id = id

    @tree.resolve @id
    promise

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

  changeState: (state, value) ->
    if @id is 'root'
      @tree.execute value, state
      return
    node = @tree.nodes[@id]
    return unless node
    return unless node.choice
    node.choice.set 'data', value
    node.choice.state = state
    @tree.resolve @id

  deliver: (value) ->
    @changeState State.FULFILLED, value
    @

  reject: (value) ->
    @changeState State.REJECTED, value
    @

  async: (fn) ->
    process.nextTick fn

  toDOT: -> @tree.toDOT()

module.exports = Thenable
