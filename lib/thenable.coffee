{State} = require './state'
Collection = require './ThenableCollection'

class Thenable
  constructor: (@tree, @options = {}) ->
    @id = 'root'

  all: (name, tasks) ->
    if typeof name isnt 'string'
      tasks = name
      name = null

    callback = (choice, data) ->
      fulfilled = []
      rejected = []
      branches = []
      composite = choice.tree name
      Collection tasks, choice, data, (state, latest) ->
        return unless state.isComplete()
        if state.countRejected() > 0
          rejects = state.rejected.filter (e) -> typeof e isnt 'undefined'
          composite.reject rejects[0]
          return
        composite.deliver state.fulfilled
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
      composite = choice.tree name
      Collection tasks, choice, data, (state, latest) ->
        return unless state.isComplete()
        if state.countFulfilled() > 0
          composite.deliver state.fulfilled
          return
        rejects = state.rejected.filter (e) -> typeof e isnt 'undefined'
        composite.reject rejects[rejects.length - 1]
      fulfilled = []
      rejected = []
      tasks.forEach (t, i) ->
        return if rejected.length
        process.nextTick ->
          try
            val = t choice, data
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
