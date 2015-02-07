exports.State =
  PENDING: 0
  FULFILLED: 1
  REJECTED: 2
  ABORTED: 3

exports.isActive = (entity) ->
  entity.state is exports.State.PENDING

exports.ensureActive = (entity) ->
  unless exports.isActive entity
    id = entity.toString()
    if id.indexOf('function (') isnt -1
      if entity.path
        id = entity.path.join '-'
      else
        id = entity.id
    type = 'Entity'
    type = entity.constructor.name if entity.constructor?.name
    throw new Error "#{type} #{id} is no longer active"
