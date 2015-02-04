trees = 0

class Tree
  constructor: (@name) ->
    trees++
    @name = "cluster#{trees}" unless @name

    # Choices indexed by id
    @choices = {}
    # Name -> id mappings
    @names = {}
    # Decisions indexed by source
    @from = {}
    # Decisions indexed by destination
    @to = {}
    # All decisions in the order registered
    @decisions = []

    @path = []
    @namedPath = []

  current: ->
    return 'root' unless @path.length
    @path[@path.length - 1]

  registerDecision: (source, dest, attributes = {}) ->
    decision =
      from: source
      to: dest
      type: 'pending'
      data: null
      attributes: attributes
      subTree: attributes.subTree
    delete attributes.subTree

    @decisions.push decision
    @from[source] = [] unless @from[source]
    @from[source].push decision
    @to[dest] = [] unless @to[dest]
    @to[dest].push decision
    decision

  removeDecision: (source, dest) ->
    return unless @from[source]
    [decision] = @from[source].filter (d) -> d.to is dest
    return unless decision
    @from[source].splice @from[source].indexOf(decision), 1
    @to[dest].splice @to[dest].indexOf(decision), 1
    @decisions.splice @decisions.indexOf(decision), 1
    null

  followChoice: (source, dest, data, attributes = {}) ->
    @registerDecision source, dest unless @to[dest]
    [decision] = @to[dest].filter (d) -> d.from is source
    decision = @registerDecision source, dest unless decision
    decision.type = 'fulfilled'
    decision.data = data
    for key, val of attributes
      continue unless val
      decision.attributes[key] = val
    @path.push dest
    @namedPath.push decision.attributes.name if decision.attributes.name
    decision

  rejectChoice: (source, dest, data, attributes = {}) ->
    @registerDecision source, dest unless @to[dest]
    [decision] = @to[dest].filter (d) -> d.from is source
    decision = @registerDecision source, dest unless decision
    decision.type = 'rejected'
    decision.data = data
    for key, val of attributes
      continue unless val
      decision.attributes[key] = val
    decision

  ignoreChoice: (source, dest, attributes = {}) ->
    @registerDecision source, dest unless @to[dest]
    [decision] = @to[dest].filter (d) -> d.from is source
    decision = @registerDecision source, dest unless decision
    for key, val of attributes
      continue unless val
      decision.attributes[key] = val
    decision.type = 'ignored'
    decision

  createId: (name) ->
    unless @names[name]
      @names[name] = []
    id = "#{name}_#{@names[name].length}".replace /-/g, '_'
    @names[name].push id
    id

  toDOT: (type = 'digraph', prefix = '', attributes = {}) ->
    dot = prefix
    dot += "#{type} #{@name} {\n"
    for key, val of attributes
      dot += "#{prefix}  #{key}=#{val};\n"

    ###
      if choice.subTree
        dot += choice.subTree.toDOT 'subgraph', "#{prefix}  ",
          color: 'lightgrey'
          style: 'filled'
        for edge in @decisions
          if edge.to is choice.id
            edge.toSub = choice.subTree.getId 'root'
          if edge.from is choice.id
            edge.fromSub = choice.subTree.path[choice.subTree.path.length - 2]
        continue
    ###
    shown = []
    for edge in @decisions
      from = edge.fromSub or edge.from
      to = edge.toSub or edge.to
      dot += "#{prefix}  #{from} -> #{to}"
      edge.attributes.label = edge.attributes.condition unless edge.attributes.label
      delete edge.attributes.label unless edge.attributes.label
      switch edge.type
        when 'ignored','pending'
          edge.attributes.style = 'dotted'
        when 'rejected'
          edge.attributes.color = 'red'
          edge.attributes.fontcolor = 'red'
        when 'fulfilled'
          edge.attributes.color = 'black'
          edge.attributes.style = 'solid'
      if Object.keys(edge.attributes).length
        dot += " ["
        attribs = []
        for key, val of edge.attributes
          attribs.push "#{key}=\"#{val}\""
        dot += attribs.join ','
        dot += "]"
      dot += ";\n"
    dot += "#{prefix}}\n"
    dot

module.exports = Tree
