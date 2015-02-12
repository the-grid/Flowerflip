Thenable = require './Thenable'
BehaviorTree = require './BehaviorTree'

module.exports = (options = {}) ->
  tree = new BehaviorTree
  new Thenable tree, options
