chai = require 'chai' unless chai
Choice = require '../lib/Choice'
{State} = require '../lib/state'

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
    it 'should provide added paths in namedPath', ->
      c = new Choice 'hello'
      chai.expect(c.path).to.eql ['hello']
      c.addPath ['foo', 'bar']
      chai.expect(c.namedPath()).to.eql []
      chai.expect(c.namedPath(true)).to.eql ['foo', 'bar']
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
    it 'should not include names with // in namedPath', ->
      pp = new Choice null, 'hello', 'hello'
      p = new Choice pp, 'ignored', '//ignored'
      c = new Choice p, 'world', 'world'
      pp.state = State.FULFILLED
      p.state = State.FULFILLED
      c.state = State.FULFILLED
      chai.expect(c.namedPath()).to.eql ['hello', 'world']
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

  describe 'assertion handling', ->
    it 'should return a chai helper', (done) ->
      c = new Choice 'expecter'
      exp = c.expect()
      chai.expect(exp).to.be.a 'function'
      exp(true).to.equal true
      done()

    it 'should handle undefined value', (done) ->
      c = new Choice 'expecter'
      exp = c.expect(undefined).to.be.a 'undefined'
      done()

    it 'should store the assertion to the choice', (done) ->
      c = new Choice 'expecter'
      foo = 'bar'
      try
        c.expect(foo).to.be.a 'boolean'
      catch e
        chai.expect(e.message).to.equal "expected 'bar' to be a boolean"
        done()

    it 'should allow passing in a value to throw', (done) ->
      c = new Choice 'expecter'
      foo = 'bar'
      try
        c.expect(foo, foo).to.be.a 'boolean'
      catch e
        data = c.get 'preconditionFailedData'
        chai.expect(e.message).to.equal "expected 'bar' to be a boolean"
        chai.expect(data).to.equal foo
        done()

  describe 'handling block type hierarchy', ->
    c = new Choice 'typer'
    it 'should recognize anything as a block', ->
      chai.expect(c.isSubtypeOf('h1', 'block')).to.equal true
      chai.expect(c.isSubtypeOf('text', 'block')).to.equal true
      chai.expect(c.isSubtypeOf('unknown', 'block')).to.equal true
    it 'should recognize any headline level anything as a headline', ->
      chai.expect(c.isSubtypeOf('h1', 'headline')).to.equal true
      chai.expect(c.isSubtypeOf('h2', 'headline')).to.equal true
      chai.expect(c.isSubtypeOf('h6', 'headline')).to.equal true
      chai.expect(c.isSubtypeOf('headline', 'headline')).to.equal true
    it 'should not recognize non-headlines as a headline', ->
      chai.expect(c.isSubtypeOf('text', 'headline')).to.equal false
      chai.expect(c.isSubtypeOf('video', 'headline')).to.equal false
    it 'should recognize any text element as a textual', ->
      chai.expect(c.isSubtypeOf('h1', 'textual')).to.equal true
      chai.expect(c.isSubtypeOf('headline', 'textual')).to.equal true
      chai.expect(c.isSubtypeOf('text', 'textual')).to.equal true
      chai.expect(c.isSubtypeOf('code', 'textual')).to.equal true
    it 'should not recognize non-text elements as a textual', ->
      chai.expect(c.isSubtypeOf('image', 'textual')).to.equal false
      chai.expect(c.isSubtypeOf('video', 'textual')).to.equal false
    it 'should recognize any media element as media', ->
      chai.expect(c.isSubtypeOf('image', 'media')).to.equal true
      chai.expect(c.isSubtypeOf('video', 'media')).to.equal true
      chai.expect(c.isSubtypeOf('audio', 'media')).to.equal true
      chai.expect(c.isSubtypeOf('article', 'media')).to.equal true
      chai.expect(c.isSubtypeOf('location', 'media')).to.equal true
      chai.expect(c.isSubtypeOf('quote', 'media')).to.equal true
    it 'should recognize any data element as data', ->
      chai.expect(c.isSubtypeOf('list', 'data')).to.equal true
      chai.expect(c.isSubtypeOf('table', 'data')).to.equal true
    it 'should recognize CtA elements as cta', ->
      chai.expect(c.isSubtypeOf('cta', 'cta')).to.equal true
    it 'should support also block objects', ->
      header =
        type: 'h1'
      chai.expect(c.isSubtypeOf(header, 'textual')).to.equal true


  describe 'get/set attributes', ->
    describe 'getting attribute on instance', ->
      it 'should return value', ->
        p = new Choice 'hello'
        p.set 'attr', 'bar'
        chai.expect(p.get('attr')).to.eql 'bar'
    describe 'getting attribute in child', ->
      it 'should return value', ->
        p = new Choice 'hello'
        p.set 'attr', 'bar'
        c = new Choice p, 'world'
        chai.expect(c.get('attr')).to.eql 'bar'
    describe 'getting attribute in grand-grand child', ->
      it 'should return value', ->
        p = new Choice 'hello'
        p.set 'attr', 'bar'
        c = new Choice p, 'child'
        gc = new Choice c, 'grand-child'
        ggc = new Choice gc, 'g-grand-child'
        chai.expect(ggc.get('attr')).to.eql 'bar'
    describe 'getting non-existant attribute', ->
      it 'should return null', ->
        p = new Choice 'hello'
        p.set 'existant', 'bar'
        chai.expect(p.get('non-existant')).to.be.a 'null'
    describe 'getting non-existant attribute in grand-grand child', ->
      it 'should return null', ->
        p = new Choice 'hello'
        c = new Choice p, 'child'
        gc = new Choice c, 'grand-child'
        ggc = new Choice gc, 'g-grand-child'
        chai.expect(ggc.get('color2')).to.be.a 'null'
    describe 'get/set globals', ->
      beforeEach ->
        Choice.reset()
      describe 'getting global', ->
        it 'should return value', (done) ->
          a = new Choice 'a'
          a.setGlobal 'foo', 'bar'
          b = new Choice 'b'
          val = b.getGlobal 'foo'
          chai.expect(val).to.equal 'bar'
          done()
      describe 'setting already set global', ->
        it 'should fail', (done) ->
          a = new Choice 'a'
          a.setGlobal 'foo', 'bar'
          b = new Choice 'b'
          func = -> b.setGlobal 'foo', 'baz'
          chai.expect(func).to.throw Error
          val = b.getGlobal 'foo'
          chai.expect(val).to.equal 'bar'
          done()
