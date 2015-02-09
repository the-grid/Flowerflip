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

    promise

  some: (name, tasks) ->
    if typeof name isnt 'string'
      tasks = name
      name = null

    callback = (choice, data) ->
      composite = new Thenable
      composite.tree.id = 'COMPOSITE-SOME'
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
                return unless fulfilled.length + rejected.length is tasks.length
                composite.deliver fulfilled
                null
              val.else (p, e) ->
                rejected.push e
                return unless fulfilled.length + rejected.length is tasks.length
                if rejected.length is tasks.length
                  composite.reject e
                else
                  composite.deliver fulfilled
                e
              return
            fulfilled.push val
            return unless fulfilled.length + rejected.length is tasks.length
            composite.deliver fulfilled
          catch e
            rejected.push e
            return unless fulfilled.length + rejected.length is tasks.length
            if rejected.length is tasks.length
              composite.reject e
            else
              composite.deliver fulfilled
      composite
    id = @tree.registerNode @id, name, 'some', callback
    promise = new Thenable @tree
    promise.id = id

    promise

  then: (name, onFulfilled) ->
    if typeof name is 'function'
      onFulfilled = name
      name = null

    id = @tree.registerNode @id, name, 'then', onFulfilled
    promise = new Thenable @tree
    promise.id = id
    promise

  else: (name, onRejected) ->
    if typeof name is 'function'
      onRejected = name
      name = null

    id = @tree.registerNode @id, name, 'else', onRejected
    promise = new Thenable @tree
    promise.id = id
    promise

  always: (name, onAlways) ->
    if typeof name is 'function'
      onAlways = name
      name = null

    id = @tree.registerNode @id, name, 'always', onAlways
    promise = new Thenable @tree
    promise.id = id
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
