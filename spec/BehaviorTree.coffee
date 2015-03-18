chai = require 'chai' unless chai
BehaviorTree = require '../lib/BehaviorTree'
{State} = require '../lib/state'
Choice = require '../lib/Choice'

describe 'Behavior Tree API', ->
  describe 'creating IDs', ->
    it 'should return immediately for unique ID', ->
      tree = new BehaviorTree
      id = tree.createId 'foo'
      chai.expect(id).to.equal 'foo'
    it 'should replace kebab with snake', ->
      tree = new BehaviorTree
      id = tree.createId 'foo-bar'
      chai.expect(id).to.equal 'foo_bar'
    it 'should return sequenced for duplicates', ->
      tree = new BehaviorTree
      tree.nodes['foo'] = {}
      id = tree.createId 'foo'
      chai.expect(id).to.equal 'foo_1'
      tree.nodes[id] = {}
      id = tree.createId 'foo'
      chai.expect(id).to.equal 'foo_2'
      tree.nodes[id] = {}
      id = tree.createId 'foo'
      chai.expect(id).to.equal 'foo_3'

  describe 'registering nodes', ->
    it 'should return the ID', ->
      tree = new BehaviorTree
      id = tree.registerNode 'root', 'then', 'then', ->
      chai.expect(id).to.equal 'then'
      id = tree.registerNode 'root', 'then', 'then', ->
      chai.expect(id).to.equal 'then_1'
    it 'should register a then as a possible destination to both previous then and else', ->
      tree = new BehaviorTree
      tree.registerNode 'root', 'foo', 'then', ->
      tree.registerNode 'foo', 'bar', 'else', ->
      tree.registerNode 'bar', 'baz', 'then', ->
      chai.expect(tree.nodes).to.have.keys ['root', 'foo', 'bar', 'baz']
      chai.expect(tree.nodes.root.destinations).to.be.an 'array'
      chai.expect(tree.nodes.root.destinations.length).to.equal 2
      chai.expect(tree.nodes.root.destinations[0].name).to.equal 'foo'
      chai.expect(tree.nodes.root.destinations[1].name).to.equal 'bar'
      chai.expect(tree.nodes.foo.destinations.length).to.equal 2
      chai.expect(tree.nodes.foo.destinations[0].name).to.equal 'bar'
      chai.expect(tree.nodes.foo.destinations[1].name).to.equal 'baz'
      chai.expect(tree.nodes.bar.destinations.length).to.equal 1
      chai.expect(tree.nodes.bar.destinations[0].name).to.equal 'baz'
      chai.expect(tree.nodes.baz.destinations.length).to.equal 0
      chai.expect(tree.nodes.baz.sources.length).to.equal 2

  describe 'handling events', ->
    it 'should call started when subscribed before root is delivered', (done) ->
      tree = new BehaviorTree null,
        Choice: Choice
      tree.started (c) ->
        chai.expect(c.get('data')).to.equal true
        done()
      tree.execute true
    it 'should call started when subscribed after root is delivered', (done) ->
      tree = new BehaviorTree null,
        Choice: Choice
      tree.execute true
      tree.started (c) ->
        chai.expect(c.get('data')).to.equal true
        done()
    it 'should call started when subscribed before choice is branched', (done) ->
      started = 0
      tree = new BehaviorTree null,
        Choice: Choice
      tree.registerNode 'root', 'then', 'then', (c, d) ->
        c.branch 'foo', ->
          chai.expect(started).to.equal 2
          done()
          d
      tree.started (c) ->
        started++
      tree.execute true
    it 'should call aborted when subscribed before choice is branched', (done) ->
      started = 0
      tree = new BehaviorTree null,
        Choice: Choice
      tree.registerNode 'root', 'then', 'then', (c, d) ->
        c.branch 'foo', ->
          d
      tree.aborted (c) ->
        chai.expect(c.choice.name).to.equal 'then'
        done()
      tree.execute true
    it 'should call branched when subscribed before choice is branched', (done) ->
      started = 0
      tree = new BehaviorTree null,
        Choice: Choice
      tree.registerNode 'root', 'then', 'then', (c, d) ->
        c.branch 'foo', ->
          d
      tree.branched (c) ->
        chai.expect(c.name).to.equal 'foo'
        done()
      tree.execute true
