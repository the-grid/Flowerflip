trees = 0

class Tree
  constructor: (@name) ->
    trees++
    @name = "tree#{trees}" unless @name
    @choices = {}
    @decisions = []
    @path = []
    @path.push @addChoice 'root',
      label: 'root'
      root: true
    @namedPath = []

  getRoot: ->
    @choices[@getId('root')]

  addChoice: (name, attributes = {}) ->
    id = @getId name
    @choices[id] =
      attributes: attributes
    id

  registerDecision: (name, type, data, attributes = {}) ->
    id = @getId name
    return unless @choices[id]

    @choices[id].type = type
    @choices[id].data = data
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

  followChoice: (name, data, attributes) ->
    @registerDecision name, 'fulfilled', data, attributes
    id = @getId name
    @path.push id
    @namedPath.push name if name

  rejectChoice: (name, data, attributes) ->
    @registerDecision name, 'rejected', data, attributes

  ignoreChoice: (name, attributes) ->
    @registerDecision name, 'ignored', null, attributes

  getId: (name) ->
    return name if @choices[name]
    "#{@name}_#{name}".replace /-/g, '_'

  toDOT: ->
    dot = ''
    dot += "digraph #{@name} {\n"
    for name, choice of @choices
      dot += "  #{name}"

      choice.attributes.shape = 'box'
      if name is @getId 'root'
        choice.attributes.shape = 'circle'
        choice.attributes.label = ''

      switch choice.type
        when 'ignored' then choice.attributes.style = 'dotted'
        when 'rejected'
          choice.attributes.color = 'red'
          choice.attributes.fontcolor = 'red'
          choice.attributes.label = choice.data.message if choice.data?.message

      if Object.keys(choice.attributes).length
        dot += " ["
        attribs = []

        for key, val of choice.attributes
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
