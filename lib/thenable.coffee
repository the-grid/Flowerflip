{State} = require './state'
Collection = require './ThenableCollection'

class Thenable
  constructor: (@tree, @options = {}) ->
    @id = 'root'
    @isFinal = false

  checkFinal: ->
    return unless @isFinal
    throw new Error "Thenable #{@id} is final"

  all: (name, tasks) ->
    do @checkFinal
    if typeof name isnt 'string'
      tasks = name
      name = null

    callback = (choice, data) ->
      fulfilled = []
      rejected = []
      branches = []
      composite = choice.tree name
      Collection tasks, choice, data, (state, latest) ->
        if state.countRejected() > 0
          state.finished = true
          rejects = state.rejected.filter (e) -> typeof e isnt 'undefined'
          composite.reject rejects[0]
          return
        return unless state.isComplete()
        composite.deliver state.fulfilled
      composite
    id = @tree.registerNode @id, name, 'all', callback
    promise = new Thenable @tree
    promise.id = id

    promise

  some: (name, tasks) ->
    do @checkFinal
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
      composite
    id = @tree.registerNode @id, name, 'some', callback
    promise = new Thenable @tree
    promise.id = id

    promise

  race: (name, tasks) ->
    do @checkFinal
    if typeof name isnt 'string'
      tasks = name
      name = null

    callback = (choice, data) ->
      composite = choice.tree name
      Collection tasks, choice, data, (state, latest) ->
        if state.countFulfilled() > 0
          state.finished = true
          fulfills = state.fulfilled.filter (f) -> typeof f isnt 'undefined'
          composite.deliver fulfills[0]
          return
        return unless state.isComplete()
        rejects = state.rejected.filter (e) -> typeof e isnt 'undefined'
        composite.reject rejects[rejects.length - 1]
      composite
    id = @tree.registerNode @id, name, 'race', callback
    promise = new Thenable @tree
    promise.id = id

    promise

  contest: (name, tasks, score = null, resolve = null) ->
    do @checkFinal
    if typeof name isnt 'string'
      resolve = score
      score = tasks
      tasks = name
      name = null

    unless typeof resolve is 'function'
      resolve = (chosen) -> true

    callback = (choice, data) ->
      composite = choice.tree name
      chosenSolutions = []
      onResult = (state, latest) ->
        return unless state.isComplete()
        if state.countFulfilled() > 0
          fulfills = []
          for f, i in state.fulfilled
            continue if typeof f is 'undefined'
            fulfills.push
              choice: state.choices[i]
              value: f
          unless typeof score is 'function'
            chosen = fulfills[0]
            chosenSolutions.push chosen
            accepted = resolve choice, chosen
            return Collection tasks, choice, data, onResult unless accepted
            composite.deliver chosenSolutions
            return
          chosen = score fulfills
          chosenSolutions.push chosen
          accepted = resolve choice, chosen
          return Collection tasks, choice, data, onResult unless accepted
          composite.deliver chosenSolutions
          return
        rejects = state.rejected.filter (e) -> typeof e isnt 'undefined'
        composite.reject rejects[rejects.length - 1]
      Collection tasks, choice, data, onResult
      composite
    id = @tree.registerNode @id, name, 'contest', callback
    promise = new Thenable @tree
    promise.id = id

    promise

  then: (name, onFulfilled) ->
    do @checkFinal
    if typeof name is 'function'
      onFulfilled = name
      name = null

    id = @tree.registerNode @id, name, 'then', onFulfilled
    promise = new Thenable @tree
    promise.id = id
    promise

  else: (name, onRejected) ->
    do @checkFinal
    if typeof name is 'function'
      onRejected = name
      name = null

    id = @tree.registerNode @id, name, 'else', onRejected
    promise = new Thenable @tree
    promise.id = id
    promise

  always: (name, onAlways) ->
    do @checkFinal
    if typeof name is 'function'
      onAlways = name
      name = null

    id = @tree.registerNode @id, name, 'always', onAlways
    promise = new Thenable @tree
    promise.id = id
    promise

  finally: (name, onFinally) ->
    if typeof name is 'function'
      onFinally = name
      name = null

    id = @tree.registerNode @id, name, 'finally', onFinally
    promise = new Thenable @tree
    promise.isFinal = true
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
