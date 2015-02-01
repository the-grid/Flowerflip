trees = 0

class Tree
  constructor: (@name) ->
    trees++
    @name = "cluster#{trees}" unless @name
    @choices = {}
    @decisions = []
    @path = []
    @path.push @addChoice 'root',
      label: 'root'
      root: true
    @namedPath = []

  getRoot: ->
    @getChoice 'root'

  getChoice: (name) ->
    @choices[@getId(name)]

  addChoice: (name, attributes = {}) ->
    id = @getId name
    id = "#{id}_#{Object.keys(@choices).length}" if @choices[id]
    @choices[id] =
      id: id
      name: name
      attributes: attributes
    id

  registerDecision: (name, type, data, attributes = {}) ->
    choice = @getChoice name
    return unless choice

    choice.type = type
    choice.data = data

    choice.subTree = attributes.subTree
    delete attributes.subTree

    if type is 'ignored'
      choice.previous = @path[@path.length - 2]
    else
      choice.previous = @path[@path.length - 1]

    attributes.type = type
    @decisions.push
      from: choice.previous
      to: choice.id
      label: name
      attributes: attributes

  followChoice: (name, data, attributes) ->
    @registerDecision name, 'fulfilled', data, attributes
    node = @getChoice name
    @path.push node.id
    @namedPath.push node.name if node.name

  rejectChoice: (name, data, attributes) ->
    @registerDecision name, 'rejected', data, attributes

  ignoreChoice: (name, attributes) ->
    @registerDecision name, 'ignored', null, attributes

  getId: (name) ->
    return name if @choices[name]
    "#{@name}_#{name}".replace /-/g, '_'

  toDOT: (type = 'digraph', prefix = '', attributes = {}) ->
    dot = prefix
    dot += "#{type} #{@name} {\n"
    for key, val of attributes
      dot += "#{prefix}  #{key}=#{val};\n"
    for name, choice of @choices
      connected = @decisions.filter (edge) ->
        edge.from is choice.id or edge.to is choice.id
      continue unless connected.length

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

      dot += "#{prefix}  #{name}"

      choice.attributes.shape = 'box'
      choice.attributes.label = typeof choice.data
      choice.attributes.label = '' unless choice.data

      if name is @getId 'root'
        choice.attributes.shape = 'Mdiamond'
        choice.attributes.label = ''

      if @decisions[@decisions.length - 1].to is choice.id
        continue if prefix.length
        choice.attributes.shape = 'Msquare'
        choice.attributes.label = ''


      switch choice.type
        when 'ignored'
          choice.attributes.style = 'dotted'
          choice.attributes.label = ''
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
      from = edge.fromSub or edge.from
      to = edge.toSub or edge.to
      dot += "#{prefix}  #{from} -> #{to}"
      if Object.keys(edge.attributes).length
        dot += " ["
        attribs = []
        edge.attributes.label = edge.label unless edge.attributes.label
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
    dot += "#{prefix}}\n"
    dot

module.exports = Tree
