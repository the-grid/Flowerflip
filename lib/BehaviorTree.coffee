PositiveResults = [
  'then'
  'all'
  'some'
  'always'
]
NegativeResults = [
  'else'
  'always'
  'root'
]
ImmediateResults = [
  'some'
  'all'
]

class BehaviorTree
  constructor: (@name) ->
    @choices =
      root:
        id: 'root'
        name: @name
        type: 'root'
        sources: []
        destinations: []

  createId: (name, seq = 0) ->
    id = name.replace /-/g, '_'
    unless @choices[id]
      # First choice with the given name
      return id

    seq++
    seqId = "#{id}_#{seq}"
    while @choices[seqId]
      seq++
      seqId = "#{id}_#{seq}"
    seqId

  registerChoice: (source, name, type, callback) ->
    unless callback
      type = name
      callback = type
      name = null

    id = @createId name or type

    unless @choices[source]
      throw new Error "Unknown source #{source} for choice #{id}"

    @choices[id] =
      id: id
      name: name
      promiseSource: source
      type: type
      callback: callback
      sources: []
      destinations: []

    @findSources @choices[id]

  findSources: (choice) ->
    gotNegative = false
    gotPositive = false

    source = @choices[choice.promiseSource]
    while source
      break if source.type is 'root' and choice.type is 'else'
      source.destinations.push choice
      choice.sources.push source
      break if choice.type in ImmediateResults
      break if source.type is 'root'
      if choice.type is 'then' and source.type in PositiveResults
        break
      if choice.type is 'else' and source.type in NegativeResults
        break
      if choice.type is 'always' and source.type in PositiveResults
        gotPositive = true
        break if gotNegative
      if choice.type is 'always' and source.type in NegativeResults
        gotNegative = true
        break if gotPositive
      source = @choices[source.promiseSource]
    choice.sources

module.exports = BehaviorTree
