exports.State =
  PENDING: 0
  RUNNING: 1
  FULFILLED: 2
  REJECTED: 3
  ABORTED: 4

exports.stateToString = (entity) ->
  state = entity.state
  state = entity unless typeof entity is 'object'
  switch state
    when 0
      return 'pending'
    when 1
      return 'running'
    when 2
      return 'fulfilled'
    when 3
      return 'rejected'
    when 4
      return 'aborted'

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
