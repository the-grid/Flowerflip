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
      subtree = choice.continue name
      composite = subtree.then (subChoice, data) ->
        Collection.run tasks, composite, subChoice, data, (state, latest) ->
          if state.countRejected() > 0
            state.finished = true
            rejects = state.getRejected().filter (e) -> typeof e isnt 'undefined'
            composite.reject rejects[0][0] or rejects[0]
            return
          if state.countAborted() > 0
            state.finished = true
            composite.reject state.aborted[state.aborted.length - 1].value
            return
          return unless state.isComplete()
          Collection.deliverBranches state, choice, subChoice, composite
          return
        return
      subtree.deliver data
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
      subtree = choice.continue name
      composite = subtree.then (subChoice, data) ->
        Collection.run tasks, composite, subChoice, data, (state, latest) ->
          return unless state.isComplete()
          if state.countFulfilled() > 0
            Collection.deliverBranches state, choice, subChoice, composite
            return
          rejects = state.getRejected().filter (e) -> typeof e isnt 'undefined'
          unless rejects.length
            rejects = state.aborted.map (a) -> a.value
          composite.reject rejects[rejects.length - 1][0] or rejects[rejects.length - 1]
          return
        return
      subtree.deliver data
      composite
    id = @tree.registerNode @id, name, 'some', callback
    promise = new Thenable @tree
    promise.id = id

    promise

  maybe: (name, tasks) ->
    do @checkFinal
    if typeof name isnt 'string'
      tasks = name
      name = null

    callback = (choice, data) ->
      subtree = choice.continue name
      composite = subtree.then (subChoice, data) ->
        Collection.run tasks, composite, subChoice, data, (state, latest) ->
          return unless state.isComplete()
          if state.countFulfilled() > 0
            Collection.deliverBranches state, choice, subChoice, composite
            return
          composite.reject data
          return
      subtree.deliver data
      composite
    id = @tree.registerNode @id, name, 'maybe', callback
    promise = new Thenable @tree
    promise.id = id

    promise

  race: (name, tasks) ->
    do @checkFinal
    if typeof name isnt 'string'
      tasks = name
      name = null

    callback = (choice, data) ->
      composite = choice.continue name
      subChoice = composite.tree.nodes['root'].choices['']
      Collection.run tasks, composite, subChoice, data, (state, latest) ->
        if state.countFulfilled() > 0
          state.finished = true
          fulfills = state.getFulfilled().filter (f) -> typeof f isnt 'undefined'
          composite.deliver fulfills[0][0] or fulfills[0]
          return
        return unless state.isComplete()
        rejects = state.getRejected().filter (e) -> typeof e isnt 'undefined'
        unless rejects.length
          rejects = state.aborted.map (a) -> a.value
        composite.reject rejects[rejects.length - 1][0] or rejects[rejects.length - 1]
        return
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
      # Auto-break unless until callback is provided
      resolve = (c, chosenSolutions) -> true

    unless typeof score is 'function'
      score = (c, fulfills, chosenSolutions) -> fulfills[0]

    callback = (choice, data) ->
      composite = choice.continue name
      subChoice = composite.tree.nodes['root'].choices['']
      chosenSolutions = []
      onResult = (state, latest) ->
        return unless state.isComplete()
        if state.countFulfilled() > 0
          fulfills = []
          for f, i in state.fulfilled
            continue unless f
            for path, option of f
              fulfills.push
                path: path
                choice: option.choice
                value: option.value
          chosen = score subChoice, fulfills, chosenSolutions
          chosenSolutions.push chosen
          accepted = resolve subChoice, chosenSolutions
          unless accepted
            Collection.run tasks, composite, subChoice, data, onResult
            return
          composite.deliver chosenSolutions.map (c) -> c.value
          return
        rejects = state.getRejected()
        unless rejects.length
          rejects = state.aborted
        composite.reject rejects[rejects.length - 1][0] or rejects[rejects.length - 1]
        return
      Collection.run tasks, composite, subChoice, data, onResult
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
    return unless node.choices['root']
    node.choices['root'].set 'data', value
    node.choices['root'].state = state
    @tree.resolve @id, 'root'

  deliver: (value) ->
    @changeState State.FULFILLED, value
    @

  reject: (value) ->
    @changeState State.REJECTED, value
    @

  toDOT: -> @tree.toDOT()

module.exports = Thenable
