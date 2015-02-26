{State} = require './state'

trees = 0

class Tree
  constructor: (@name) ->
    @id = trees++
    @name = @id unless @name
    @nodes = {}
    @edges = []

  addNode: (id, name, data, state, subtrees) ->
    #console.log "addNode", id, name
    @nodes[id] =
      id: id
      name: name
      data: data
      state: state
      subtrees: subtrees

  addEdge: (src, dest, name, state) ->
    for e in @edges
      return if e.from is src and e.to is dest
    #console.log "addEdge", src, dest
    unless @nodes[src]
      throw new Error "Source node #{src} not registered"
    unless @nodes[dest]
      throw new Error "Destination node #{dest} not registered"
    @edges.push
      from: src
      to: dest
      name: name
      state: state

  getRoot: -> 'root'
  getLeaf: ->
    fulfilled = @edges.filter (e) -> e.state is State.FULFILLED
    return 'root' unless fulfilled.length
    fulfilled[fulfilled.length - 1].to

  cleanData: (d) ->
    d.replace /"/g, '\''

  dataToDot: (data) ->
    d = data
    if typeof data is 'object'
      if data.data
        d = data.data
      else
        d = data
      if typeof d is 'object'
        keys = Object.keys(d).filter (k) -> k not in ['items', 'itemsEaten', 'blocksEaten']
        return "{#{@cleanData(keys.join(','))}}"
    typeof d

  nodeToDot: (prefix, id, node) ->
    if node.subtrees and node.subtrees.length
      dot = ''
      for sub in node.subtrees
        dot += sub.toDOT 'subgraph', "#{prefix}  "
        for edge in @edges
          if edge.to is node.id
            edge.subTo = [] unless edge.subTo
            edge.subTo.push "t#{sub.id}_#{sub.getRoot()}"
          if edge.from is node.id
            edge.subFrom = [] unless edge.subFrom
            edge.subFrom.push "t#{sub.id}_#{sub.getLeaf()}"
      return dot

    dot = "#{prefix}  t#{id}_#{node.id}"
    attributes = {}
    attributes.shape = 'box'
    labelParts = []
    labelParts.push node.name if node.name
    labelParts.push @dataToDot node.data if node.data
    attributes.label = labelParts.join ' '
    attributes.shape = 'Mdiamond' if node.id is @getRoot()
    attributes.shape = 'Msquare' if node.id is @getLeaf()

    dot += " ["
    attribs = []
    for key, val of attributes
      if typeof val is 'boolean'
        attribs.push "#{key}=#{val}"
        continue
      attribs.push "#{key}=\"#{val}\""
    dot += attribs.join ','
    dot += "]"
    dot += ";\n"
    dot

  edgeToDot: (prefix, id, edge) ->
    froms = edge.subFrom or ["t#{id}_#{edge.from}"]
    tos = edge.subTo or ["t#{id}_#{edge.to}"]

    dot = ''
    for from in froms
      for to in tos
        dot += "#{prefix}  #{from} -> #{to}"
        attributes = {}
        attributes.label = edge.name or edge.type

        edge.state = State.PENDING if typeof edge.state is 'undefined'

        switch edge.state
          when State.PENDING
            attributes.style = 'dotted'
          when State.REJECTED
            attributes.color = 'red'

        dot += " ["
        attribs = []
        for key, val of attributes
          if typeof val is 'boolean'
            attribs.push "#{key}=#{val}"
            continue
          attribs.push "#{key}=\"#{val}\""
        dot += attribs.join ','
        dot += "]"
        dot += ";\n"
    dot

  toDOT: (type = 'digraph', prefix = '', attributes = {}) ->
    dot = prefix
    name = if prefix then "cluster#{@id}" else @name
    attributes.label = @name if @name and typeof @name is 'string'
    dot += "#{type} #{name} {\n"
    for key, val of attributes
      dot += "#{prefix}  #{key}=#{val};\n"

    for id, node of @nodes
      dot += @nodeToDot prefix, @id, node

    for edge in @edges
      dot += @edgeToDot prefix, @id, edge

    dot += "#{prefix}}\n"

    dot

module.exports = Tree
