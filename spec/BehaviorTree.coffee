chai = require 'chai' unless chai
BehaviorTree = require '../lib/BehaviorTree'

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
      tree.choices['foo'] = {}
      id = tree.createId 'foo'
      chai.expect(id).to.equal 'foo_1'
      tree.choices[id] = {}
      id = tree.createId 'foo'
      chai.expect(id).to.equal 'foo_2'
      tree.choices[id] = {}
      id = tree.createId 'foo'
      chai.expect(id).to.equal 'foo_3'

  describe 'registering choices', ->
    it 'should register a then as a possible destination to both previous then and else', ->
      tree = new BehaviorTree
      tree.registerChoice 'root', 'foo', 'then', ->
      tree.registerChoice 'foo', 'bar', 'else', ->
      tree.registerChoice 'bar', 'baz', 'then', ->
      chai.expect(tree.choices).to.have.keys ['root', 'foo', 'bar', 'baz']
      chai.expect(tree.choices.root.destinations).to.be.an 'array'
      chai.expect(tree.choices.root.destinations.length).to.equal 1
      chai.expect(tree.choices.root.destinations[0].name).to.equal 'foo'
      chai.expect(tree.choices.foo.destinations.length).to.equal 2
      chai.expect(tree.choices.foo.destinations[0].name).to.equal 'bar'
      chai.expect(tree.choices.foo.destinations[1].name).to.equal 'baz'
      chai.expect(tree.choices.bar.destinations.length).to.equal 1
      chai.expect(tree.choices.bar.destinations[0].name).to.equal 'baz'
      chai.expect(tree.choices.baz.destinations.length).to.equal 0
      chai.expect(tree.choices.baz.sources.length).to.equal 2
