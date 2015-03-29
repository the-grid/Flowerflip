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
            rejects = state.getAborted()
            composite.reject rejects[0][0] or rejects[0]
            return
          return unless state.isComplete()
          Collection.deliverBranches state, choice, subChoice, composite
          return
      subtree.deliver data
      composite
    id = @tree.registerNode @id, name, 'all', callback
    promise = new Thenable @tree
    promise.id = id

    promise

  none: (name, tasks) ->
    do @checkFinal
    if typeof name isnt 'string'
      tasks = name
      name = null

    callback = (choice, data) ->
      subtree = choice.continue name
      composite = subtree.then (subChoice, data) ->
        Collection.run tasks, composite, subChoice, data, (state, latest) ->
          if state.countFulfilled() > 0
            state.finished = true
            rejects = state.getFulfilled().filter (e) -> typeof e isnt 'undefined'
            composite.reject rejects[0][0] or rejects[0]
            return
          return unless state.isComplete()
          rejects = state.getRejected().filter (e) -> typeof e isnt 'undefined'
          unless rejects.length
            rejects = state.getAborted()
          composite.fulfill rejects[0][0] or rejects[0]
          return
      subtree.deliver data
      composite
    id = @tree.registerNode @id, name, 'none', callback
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
          return state unless state.isComplete()
          if state.countFulfilled() > 0
            Collection.deliverBranches state, choice, subChoice, composite
            return
          rejects = state.getRejected().filter (e) -> typeof e isnt 'undefined'
          unless rejects.length
            rejects = state.getAborted()
          composite.reject rejects[rejects.length - 1]?[0] or rejects[rejects.length - 1]
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

  race: (name, tasks, qualify = null) ->
    do @checkFinal
    if typeof name isnt 'string'
      qualify = tasks
      tasks = name
      name = null

    unless typeof qualify is 'function'
      # Pick the first one
      qualify = (solution, previousSolutions) -> solution

    callback = (choice, data) ->
      subtree = choice.continue name
      composite = subtree.then (subChoice, data) ->
        Collection.run tasks, composite, subChoice, data, (state, latestValue, latest) ->
          if state.countFulfilled() > 0
            result = qualify latest, state.getFulfilled()
            return unless result.choice
            state.finished = true
            subChoice.registerSubleaf result.choice, true, true
            composite.deliver result.value
            return
          return state unless state.isComplete()
          rejects = state.getRejected().filter (e) -> typeof e isnt 'undefined'
          unless rejects.length
            rejects = state.getAborted()
          composite.reject rejects[rejects.length - 1][0] or rejects[rejects.length - 1]
      subtree.deliver data
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

    tree = @tree
    chosenSolutions = []
    callback = (choice, data) ->
      subtree = choice.continue name
      subCallback = (subChoice, data) ->
        onResult = (state, latest) ->
          return state unless state.isComplete()
          if state.countFulfilled() is 0
            rejects = state.getRejected()
            unless rejects.length
              rejects = state.getAborted()
            composite.reject rejects[rejects.length - 1][0] or rejects[rejects.length - 1]
            return

          fulfills = []
          for f, i in state.fulfilled
            continue unless f
            for path, option of f
              fulfills.push
                path: path
                choice: option.choice
                value: option.value
          chosen = score subChoice, fulfills, chosenSolutions
          unless chosen.choice
            subChoice.error "Chosen solution doesn't contain a choice node"
            return
          subChoice.registerSubleaf chosen.choice, true, true
          for f in fulfills
            continue unless f.choice
            subChoice.registerSubleaf f.choice, false
          chosenSolutions.push chosen

          accepted = resolve subChoice, chosenSolutions
          unless accepted
            tree.insertNodeAfter choice.id, name, 'contest', callback
            choice.registerSubleaf subChoice, true, true
            composite.deliver data
            return
          state.finished = true
          composite.deliver chosenSolutions.map (c) -> c.value
          return
        Collection.run tasks, composite, subChoice, data, onResult
      composite = subtree.then subCallback
      subtree.deliver data
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

  catch: (name, onRejected) ->
    @else name, onRejected

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
