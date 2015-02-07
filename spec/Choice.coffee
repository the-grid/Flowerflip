chai = require 'chai' unless chai
Choice = require '../lib/Choice'

describe 'Choice node API', ->
  describe 'with no parents', ->
    it 'should not allow instantiating without an ID', ->
      inst = ->
        c = new Choice
      chai.expect(inst).to.throw Error
    it 'should contain itself in the path', ->
      c = new Choice 'hello'
      chai.expect(c.path).to.eql ['hello']
      chai.expect(c.source).to.be.a 'null'
    it 'should not provide items if it has not been initialized with any', (done) ->
      validated = false
      c = new Choice 'hello'
      item = c.getItem (i) -> validated = true
      chai.expect(item).to.be.a 'null'
      chai.expect(validated).to.equal false
      done()

    it 'should call validation callback for the item in array', (done) ->
      validated = false
      providedItem =
        id: 'foo'
      c = new Choice 'hello'
      c.attributes.items.push providedItem
      item = c.getItem (i) ->
        validated = true if i is providedItem
      chai.expect(item).to.equal providedItem
      chai.expect(validated).to.equal true
      done()

    it 'should not return an item once it has been eaten', (done) ->
      providedItem =
        id: 'foo'
      c = new Choice 'hello'
      c.attributes.items.push providedItem
      chai.expect(c.availableItems().length).to.equal 1
      item = c.getItem (i) -> true
      chai.expect(item).to.equal providedItem

      c.eatItem item
      chai.expect(c.availableItems().length).to.equal 0
      nextItem = c.getItem (i) -> true
      chai.expect(nextItem).to.be.a 'null'
      done()

  describe 'with a parent', ->
    it 'should contain the parent in its path', ->
      p = new Choice 'hello'
      c = new Choice p, 'world'
      chai.expect(c.path).to.eql ['hello', 'world']
    it 'should not have mutated the source path', ->
      p = new Choice 'hello'
      c = new Choice p, 'world'
      chai.expect(p.path).to.eql ['hello']
    it 'should not provide items if it has not been initialized with any', (done) ->
      validated = false
      p = new Choice 'hello'
      c = new Choice p, 'world'
      item = c.getItem (i) -> validated = true
      chai.expect(item).to.be.a 'null'
      chai.expect(validated).to.equal false
      done()

    it 'should call validation callback for the item in array', (done) ->
      providedItem =
        id: 'foo'
      p = new Choice 'hello'
      p.attributes.items.push providedItem
      validated = false
      c = new Choice p, 'world'
      item = c.getItem (i) ->
        validated = true if i is providedItem
      chai.expect(item).to.equal providedItem
      chai.expect(validated).to.equal true
      done()

    it 'should not return an item once it has been eaten', (done) ->
      providedItem =
        id: 'foo'
      p = new Choice 'hello'
      p.attributes.items.push providedItem
      c = new Choice p, 'world'
      chai.expect(c.availableItems().length).to.equal 1
      item = c.getItem (i) -> true
      chai.expect(item).to.equal providedItem

      c.eatItem item
      chai.expect(c.availableItems().length).to.equal 0
      nextItem = c.getItem (i) -> true
      chai.expect(nextItem).to.be.a 'null'
      done()

    it 'should have the item available in the parent node after eating in child', (done) ->
      providedItem =
        id: 'foo'
      p = new Choice 'hello'
      p.attributes.items.push providedItem
      c = new Choice p, 'world'
      chai.expect(c.availableItems().length).to.equal 1
      item = c.getItem (i) -> true
      chai.expect(item).to.equal providedItem

      c.eatItem item
      chai.expect(c.availableItems().length).to.equal 0
      chai.expect(p.availableItems().length).to.equal 1
      done()
