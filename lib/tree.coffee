trees = 0

class Tree
  constructor: (@name) ->
    trees++
    @name = "tree#{trees}" unless @name
    @nodes = {}
    @choices = {}
    @paths = {}
    @decisions = []
    @edges = []
    @path = []
    @path.push @addChoice 'root',
      label: 'root'
      root: true
    @namedPath = []

  getRoot: ->
    @nodes[@getId('root')]

  addChoice: (name, attributes = {}) ->
    id = @getId name
    @choices[id] = attributes
    id

  registerDecision: (name, type, attributes = {}) ->
    id = @getId name
    return unless @choices[id]

    @choices[id].type = type
    if type is 'ignored'
      @choices[id].previous = @path[@path.length - 2]
    else
      @choices[id].previous = @path[@path.length - 1]

    attributes.type = type
    @decisions.push
      from: @choices[id].previous
      to: id
      label: name
      attributes: attributes

  followChoice: (name, attributes) ->
    @registerDecision name, 'fulfilled', attributes
    id = @getId name
    @path.push id
    @namedPath.push name if name

  rejectChoice: (name, attributes) ->
    @registerDecision name, 'rejected', attributes

  ignoreChoice: (name, attributes) ->
    @registerDecision name, 'ignored', attributes

  getId: (name) ->
    return name if @nodes[name]
    "#{@name}_#{name}".replace /-/g, '_'

  addNode: (name, attributes = {}) ->
    id = @getId name
    attributes.name = name
    @nodes[id] = attributes
    id

  addEdge: (from, to, attributes = {}) ->
    fromId = @getId from
    toId = @getId to
    @edges.push
      from: fromId
      to: toId
      attributes: attributes

  toDOT: ->
    dot = ''
    dot += "digraph #{@name} {\n"
    for name, attributes of @choices
      dot += "  #{name}"

      attributes.shape = 'box'
      if name is @getId 'root'
        attributes.shape = 'circle'
        attributes.label = ''

      if Object.keys(attributes).length
        dot += " ["
        attribs = []
        switch attributes.type
          when 'ignored' then attributes.style = 'dotted'
          when 'rejected'
            attributes.color = 'red'
            attributes.fontcolor = 'red'

        for key, val of attributes
          if typeof val is 'boolean'
            attribs.push "#{key}=#{val}"
            continue
          attribs.push "#{key}=\"#{val}\""
        dot += attribs.join ','
        dot += "]"
      dot += ";\n"

    for edge in @decisions
      dot += "  #{edge.from} -> #{edge.to}"
      if Object.keys(edge.attributes).length
        dot += " ["
        attribs = []
        edge.attributes.label = edge.label
        switch edge.attributes.type
          when 'ignored' then edge.attributes.style = 'dotted'
          when 'rejected'
            edge.attributes.color = 'red'
            edge.attributes.fontcolor = 'red'
        for key, val of edge.attributes
          attribs.push "#{key}=\"#{val}\""
        dot += attribs.join ','
        dot += "]"
      dot += ";\n"
    dot += "}\n"
    dot

module.exports = Tree
