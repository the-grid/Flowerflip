class SubtreeResults
  constructor: (@tasks, @choice) ->
    @tasks = 1 unless @tasks
    @finished = false
    @branches = []
    @aborted = []
    @fulfilled = []
    @rejected = []

  countTasks: ->
    @tasks
  countFulfilled: ->
    full = 0
    for f in @fulfilled
      continue unless f
      full += Object.keys(f).length
    full
  countRejected: ->
    rej = 0
    for r in @rejected
      continue unless r
      rej += Object.keys(r).length
    rej
  countAborted: (branched = false) ->
    aborted = 0
    for a in @aborted
      continue unless a
      for k,v of a
        continue unless v.branched is branched
        aborted++
    aborted
  isComplete: ->
    return @finished if @finished
    i = 0
    complete = true
    while i < @tasks
      fulfilled = if @fulfilled[i] then Object.keys(@fulfilled[i]).length else 0
      rejected = if @rejected[i] then Object.keys(@rejected[i]).length else 0
      branched = if @branches[i] then Object.keys(@branches[i]).length else 0
      aborted = if @aborted[i] then Object.keys(@aborted[i]).length else 0
      #console.log "#{@choice.treeId} #{@choice} #{i} #{fulfilled} #{rejected} #{aborted} #{branched}"
      if fulfilled + rejected + aborted < branched + 1
        complete = false
      i++
    @finished = complete
    return @finished

  getFulfilled: -> @getResults @fulfilled
  getRejected: -> @getResults @rejected
  getAborted: ->
    collection = @aborted
    collection.map (f, i) ->
      return unless f
      keys = Object.keys f
      keys = keys.filter (k) -> collection[i][k].branched isnt true
      if keys.length is 1
        return collection[i][keys[0]].value
      keys.map (k) -> collection[i][k].value
  getResults: (collection) ->
    collection.map (f, i) ->
      return unless f
      keys = Object.keys f
      if keys.length is 1
        return collection[i][keys[0]].value
      keys.map (k) -> collection[i][k].value

  getBranches: (collection = null) ->
    collection = @fulfilled unless collection
    return [] unless collection.length
    fulfilled = []
    for r, t in collection
      unless typeof r is 'object'
        fulfilled[t] = [undefined]
        continue
      fulfilled[t] = Object.keys(r).map (k) -> r[k]

    combine = (list) ->
      prefixes = list[0]
      return prefixes unless list.length > 1
      combinations = combine list.slice 1
      prefixes.reduce (memo, prefix) ->
        memo.concat combinations.map (combination) -> [prefix].concat combination
      , []

    return [fulfilled[0]] if fulfilled.length is 1

    f = combine fulfilled
    return f

  handleResult: (collection, idx, choice, value, callback = ->) ->
    return if @finished
    path = if choice then choice.toString() else ''
    collection[idx] = {} unless collection[idx]
    collection[idx][path] =
      choice: choice
      value: value
    callback @, value

  registerTree: (idx, tree, onResult) ->
    tree.branched (c) =>
      path = if c then c.toString() else ''
      @branches[idx] = {} unless @branches[idx]
      @branches[idx][path] = c
    tree.aborted (a) =>
      path = if a.choice then a.choice.toString() else ''
      @aborted[idx] = {} unless @aborted[idx]
      @aborted[idx][path] = a
      return unless @isComplete()
      # Every task aborted
      onResult @, a.value

  toJSON: ->
    state =
      tasks: @tasks
      finished: @finished
      branches: @branches.slice 0
      aborted: @aborted.slice 0
      fulfilled: @fulfilled.slice 0
      rejected: @rejected.slice 0
    state

module.exports = SubtreeResults
