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
    it 'should contain full path in its toString', ->
      c = new Choice 'world'
      chai.expect('' + c).to.equal 'world'
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

    it 'should contain full path in its toString', ->
      p = new Choice 'hello'
      c = new Choice p, 'world'
      chai.expect('' + c).to.equal 'hello-world'
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

  describe 'branching', ->
    it 'should throw exception if there are no subscribers', ->
      c = new Choice 'foo'
      inst = ->
        c.branch 'bar'
      chai.expect(inst).to.throw Error

    it 'should call the onBranch callback', (done) ->
      c = new Choice 'foo'
      c.onBranch = (original, branch, callback) ->
        chai.expect(original).to.equal c
        chai.expect(original.path).to.eql ['foo']
        chai.expect(original.id).to.equal 'foo'
        chai.expect(branch.path).to.eql ['bar']
        chai.expect(branch.id).to.equal 'bar'
        chai.expect(callback).to.be.a 'function'
        done()
      c.branch 'bar'

    it 'should contain the eaten item of the original', (done) ->
      c = new Choice 'foo'
      providedItem =
        id: 'foo'
      c.attributes.items.push providedItem

      c.onBranch = (original, branch, callback) ->
        # We should have the same data in both
        chai.expect(original.availableItems()).to.eql []
        chai.expect(original.attributes.itemsEaten).to.eql [providedItem]
        chai.expect(branch.availableItems()).to.eql []
        chai.expect(branch.attributes.itemsEaten).to.eql [providedItem]

        # Ensure these have been cloned
        chai.expect(branch.attributes.items).to.not.equal original.attributes.items
        chai.expect(branch.attributes.itemsEaten).to.not.equal original.attributes.itemsEaten
        done()

      c.eatItem c.getItem()

      c.branch 'bar'

    it 'should throw error on operations on original after branching off', (done) ->
      orig = new Choice 'foo'
      one =
        id: 'one'
      two =
        id: 'two'

      orig.attributes.items.push one
      orig.attributes.items.push two

      orig.onBranch = (original, branch, callback) ->
        callback branch

      b = orig.branch 'bar', (branch) ->
        branch.eatItem branch.getItem (i) ->
          chai.expect(i.id).to.equal 'two'

      fail = ->
        orig.eatItem orig.getItem (i) ->
      chai.expect(fail).to.throw Error

      try
        orig.getItem()
      catch e
        chai.expect(e.message).to.equal 'Choice foo is no longer active'

      done()

    it 'should allow branches to diverge', (done) ->
      orig = new Choice 'foo'
      one =
        id: 'one'
      two =
        id: 'two'

      orig.attributes.items.push one
      orig.attributes.items.push two

      orig.onBranch = (original, branch, callback) ->
        callback branch

      c = orig.branch 'foo', (branch) ->
        branch.eatItem branch.getItem (i) ->
          chai.expect(i.id).to.equal 'one'
      b = orig.branch 'bar', (branch) ->
        branch.eatItem branch.getItem (i) ->
          chai.expect(i.id).to.equal 'two'

      chai.expect(c.toString()).to.equal 'foo'
      chai.expect(c.availableItems()).to.eql [two]
      chai.expect(c.attributes.itemsEaten).to.eql [one]
      chai.expect(b.toString()).to.equal 'bar'
      chai.expect(b.availableItems()).to.eql [one]
      chai.expect(b.attributes.itemsEaten).to.eql [two]

      done()
