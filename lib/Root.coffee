Thenable = require './Thenable'
BehaviorTree = require './BehaviorTree'
Choice = require './Choice'

module.exports = (name, options = {}) ->
  options.Choice = Choice unless options.Choice
  tree = new BehaviorTree null, options
  new Thenable tree, options
