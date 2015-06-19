isSubtypeOf = (type, checkType) ->
  if typeof type is 'object'
    type = type.type

  # TODO: Parse from The Grid JSON Schema
  return true if checkType is 'block'
  return true if type is checkType
  if checkType is 'textual'
    return true if type in ['text', 'code', 'quote']
    return isSubtypeOf type, 'headline'
  if checkType is 'media'
    return type in ['image', 'video', 'audio', 'article', 'location', 'quote']
  if checkType is 'headline'
    return type in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
  if checkType is 'data'
    return type in ['list', 'table']
  false

module.exports =
  isSubtypeOf: isSubtypeOf
