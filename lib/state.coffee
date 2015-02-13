exports.State =
  PENDING: 0
  RUNNING: 1
  FULFILLED: 2
  REJECTED: 3
  ABORTED: 4

exports.isActive = (entity) ->
  entity.state in [exports.State.PENDING, exports.State.RUNNING]

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
