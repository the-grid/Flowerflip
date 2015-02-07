Tree = require './tree'

{State} = require './state'

PositiveResults = [
  'then'
  'tree'
  'all'
  'some'
  'always'
]
NegativeResults = [
  'else'
  'always'
  'tree'
]

class Thenable
  constructor: (@decisionTree, @options = {}) ->
    @id = null
    @parent = null
    @type = null
    @state = State.PENDING
    @name = @options.name
    @value = null
    @subscribers = []
    @decisionTree = new Tree unless @decisionTree
    @subTree = null
    @path = @decisionTree.path
    @namedPath = @decisionTree.namedPath

  findParents: (attributes) ->
    #console.log 'findParents', @id, @type, @parent?.id
    attributes.subTree = @subTree
    attributes.condition = @type
    return if @type in ['some', 'all']
    ###
    unless @parent
      return if @type is 'some'
      @parent =
        id: 'root'
      @decisionTree.registerDecision 'root', @id, attributes
      return
    ###
    return unless @parent
    parent = @parent

    gotNegative = false
    gotPositive = false

    while parent
      #console.log @id, @type, parent.id, parent.type
      if @type is 'else' and parent is @parent and parent.type in PositiveResults
        parent = @parent.parent
        continue
      @decisionTree.registerDecision parent.id, @id, attributes
      if @type is 'then' and parent.type in PositiveResults
        break
      if @type is 'else' and parent.type in NegativeResults
        break
      if @type is 'always' and parent.type in PositiveResults
        gotPositive = true
        break if gotNegative
      if @type is 'always' and parent.type in NegativeResults
        gotNegative = true
        break if gotPositive
      break if @type in ['some', 'tree', 'all']
      parent = parent.parent

  tree: (name, callback) ->
    if typeof name is 'function'
      callback = name
      name = null

    @id = @decisionTree.createId(name or 'tree')
    @type = 'tree'
    unless @parent
      @parent =
        id: 'root'
    subTree = new Tree
    @findParents
      name: name
      subTree: subTree

    promise = new Thenable @decisionTree
    promise.parent = @
    @async =>
      try
        @decisionTree.followChoice @parent.id, @id
        val = callback subTree
        if val and typeof val.then is 'function' and typeof val.else is 'function'
          val.then (ret) =>
            promise.deliver ret
          val.else (e) =>
            promise.reject e
          return
        promise.deliver val
      catch e
        promise.reject e
    promise

  branch: (name, callback) ->
    @

  contest: ->
    @

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

    composite = new Thenable @decisionTree
    composite.type = 'some'
    composite.id = @decisionTree.createId(name or 'some')
    composite.parent = @parent

    fulfilled = []
    rejected = []
    tasks.forEach (t, i) =>
      tName = t.name or "some#{i}"
      tId = @decisionTree.createId tName
      onFulfilled = (path, data) =>
        @decisionTree.registerDecision @parent.id, tId,
          condition: 'then'
          name: t.name
        @decisionTree.registerDecision tId, composite.id,
          condition: 'some'
        @decisionTree.removeDecision @parent.id, composite.id
        @decisionTree.followChoice @parent.id, tId
        val = t data
        if val and typeof val.then is 'function' and typeof val.else is 'function'
          val.then (p, d) =>
            fulfilled.push d
            @decisionTree.followChoice tId, composite.id, d
            return unless fulfilled.length + rejected.length is tasks.length
            composite.deliver fulfilled
            d
          val.else (p, e) =>
            rejected.push e
            @decisionTree.rejectChoice tId, composite.id, e
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

    @id = @decisionTree.createId(name or 'then')
    @type = 'then'
    @findParents
      name: name
      condition: 'then'

    promise = new Thenable @decisionTree
    promise.parent = @

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

    @id = @decisionTree.createId(name or 'else')
    @type = 'else'
    @findParents
      name: name

    promise = new Thenable @decisionTree
    promise.parent = @
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

    @id = @decisionTree.createId(name or 'always')
    @type = 'always'
    @findParents
      name: name
      condition: 'always'

    promise = new Thenable @decisionTree
    promise.parent = @
    @subscribers.push
      name: name
      promise: promise
      always: onAlways

    do @resolve
    promise

  changeState: (state, value, parent) ->
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
    @parent = parent if parent
    do @resolve
    @state

  deliver: (value, parent) ->
    ###
    if not @parent?.id or @parent.id is 'root'
      id = @decisionTree.createId 'start'
      @decisionTree.followChoice 'root', id, value
      @parent =
        id: id
        type: 'start'
    ###

    @changeState State.FULFILLED, value, parent
    @

  reject: (value, parent) ->
    ###
    unless @parent
      @decisionTree.rejectChoice 'root', @id, value
    ###

    @changeState State.REJECTED, value, parent
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
        if @id and @parent?.decisionTree is @decisionTree
          @decisionTree.ignoreChoice parent, @id,
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
              if @id and @parent?.decisionTree is @decisionTree
                @decisionTree.followChoice parent, @id, ret,
                  name: sub.name
              sub.promise.changeState State.FULFILLED, ret if sub.promise
            ret
          val.else (path, e) =>
            if @id and @parent?.decisionTree is @decisionTree
              @decisionTree.rejectChoice parent, @id
                name: sub.name
            sub.promise.changeState State.REJECTED, e, @parent if sub.promise
            e
          continue
        # Straight-up value returned
        if @id and @parent?.decisionTree is @decisionTree
          @decisionTree.followChoice parent, @id, val,
            name: sub.name
        sub.promise.changeState State.FULFILLED, val if sub.promise
      catch e
        if @id and @parent?.decisionTree is @decisionTree
          @decisionTree.rejectChoice parent, @id, val,
            name: sub.name
        sub.promise.changeState State.REJECTED, e, @parent if sub.promise

  async: (fn) ->
    process.nextTick fn

  toDOT: -> @decisionTree.toDOT()

module.exports = Thenable
