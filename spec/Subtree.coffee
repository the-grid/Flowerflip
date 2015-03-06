chai = require 'chai' unless chai
Choice = require '../lib/Choice'
Root = require '../lib/Root'

describe 'Subtrees', ->

  describe 'child of then', ->

    testChild = (child, expected) ->
      describe "then(child)", ->
        it "it should return #{expected}", (done) ->
          t = Root()
          t.deliver {}
          .then child
          .then (n,d) ->
            child: d
            state: 'w-child'
          .else (n,d) ->
            child: d
            state: 'wo-child'
          .finally (c, d) ->
            chai.expect(d).to.eql expected
            done()
      describe "then -> child", ->
        it "it should return #{expected}", (done) ->
          t = Root()
          t.deliver {}
          .then (n,d) ->
            child n,d
          .then (n,d) ->
            child: d
            state: 'w-child'
          .else (n,d) ->
            child: d
            state: 'wo-child'
          .finally (c, d) ->
            chai.expect(d).to.eql expected
            done()

      describe "then -> child.then", ->
        it "it should return #{expected}", (done) ->
          t = Root()
          t.deliver {}
          .then (n,d) ->
            child n,d
            .then (n,d) ->
              child: d
              state: 'w-child'
          .else (n,d) ->
            child: d
            state: 'wo-child'
          .finally (c, d) ->
            chai.expect(d).to.eql expected
            done()

    describe 'succeed via return', ->
      child = (parent, data) ->
        parent.tree 'child'
        .deliver data
        .then (c, d) ->
          return "yep"
      testChild child,
        child:'yep'
        state:'w-child'

    describe 'failed via throw', ->
      child = (parent, data) ->
        parent.tree 'child'
        .deliver data
        .then ->
          throw "failed"
        .then ->
          "ignore this"
        .then ->
          "ignore this too"
      testChild child,
        child:'failed'
        state:'wo-child'

    describe 'failed via abort', ->
      child = (parent, data) ->
        parent.tree 'child'
        .deliver data
        .then (c, d) ->
          c.abort "nope", "aborted"
        .then ->
          "ignore this"
        .else ->
          "ignore this too"
      testChild child,
        child:'aborted'
        state:'wo-child'

    describe 'succeed with thrown grandchild', ->
      grandchild = (parent, data) ->
        parent.tree 'grandchild'
        .deliver data
        .then ->
          throw "failed"
        .then ->
          "ignore this"
      child = (parent, data) ->
        parent.tree 'child'
        .deliver data
        .then grandchild
        .else (c, d) ->
          chai.expect(d).to.equal 'failed'
          d
        .then (c, d) ->
          return "yep"
      testChild child,
        child:'yep'
        state:'w-child'

    describe 'succeed with aborted grandchild', ->
      # to ensure abort doesn't bubble up beyond grandchild tree
      grandchild = (parent, data) ->
        parent.tree 'grandchild'
        .deliver data
        .then (c, d) ->
          c.abort "nope", "aborted"
        .then ->
          "ignore this"
        .else ->
          "ignore this too"
      child = (parent, data) ->
        parent.tree 'child'
        .deliver data
        .then grandchild
        .else (c, d) ->
          chai.expect(d).to.equal 'aborted'
          d
        .then (c, d) ->
          return "yep"
      testChild child,
        child:'yep'
        state:'w-child'

    describe 'recursive subchildren', ->
      count = 0
      child = (parent, data) ->
        parent.tree 'child'
        .deliver data
        .then (c, d) ->
          throw count if count is 5
          count++
          d
        .then child
        .else (c, d) ->
          return "yep #{count}"
        .then (c, d) ->
          return "yep #{count}"
      testChild child,
        child:'yep 5'
        state:'w-child'


  describe 'get & set', ->

    describe 'non-existent attribute lookup in tree', ->
      it 'should return null', (done) ->

        direct = (orig, data) ->
          subtree = orig.tree 'directcalc'
          subtree.deliver data
          t = subtree.then 'tripled', (c, d) ->
            chai.expect(c.get('non-existant1')).to.equal null
            d * 3

        t = Root()
        t.deliver 5
        .all [direct]
        .finally (c, res) ->
          chai.expect(c.get('non-existant2')).to.equal null
          chai.expect(res).to.be.an 'array'
          chai.expect(res).to.eql [
            15
          ]
          done()

    describe 'non-existant attribute lookup in continue tree', ->
      it 'should return null', (done) ->
        direct = (orig, data) ->
          subtree = orig.continue 'directcalc'
          subtree.deliver data
          t = subtree.then 'tripled', (c, d) ->
            chai.expect(c.get('non-existant1')).to.equal null
            d * 3

        t = Root()
        t.deliver 5
        .all [direct]
        .finally (c, res) ->
          chai.expect(c.get('non-existant2')).to.equal null
          chai.expect(res).to.be.an 'array'
          chai.expect(res).to.eql [ 15 ]
          done()

    describe 'attribute lookup in continue tree', ->
      it 'should return null', (done) ->
        direct = (orig, data) ->
          subtree = orig.continue 'directcalc'
          subtree.deliver data
          t = subtree.then 'tripled', (c, d) ->
            c.set 'existant2', 'foo'
            chai.expect(c.get('non-existant1')).to.equal null
            d * 3

        t = Root()
        t.deliver 5
        .all [direct]
        .finally (c, res) ->
          chai.expect(c.get('existant2')).to.equal 'foo'
          chai.expect(res).to.be.an 'array'
          chai.expect(res).to.eql [ 15 ]
          done()

    describe 'attribute lookup in parent continue tree', ->
      it 'should return null', (done) ->
        direct = (orig, data) ->
          subtree = orig.continue 'directcalc'
          subtree.deliver data
          t = subtree.then 'tripled', (c, d) ->
            chai.expect(c.get('non-existant1')).to.equal null
            chai.expect(c.get('existant2')).to.equal 'foo'
            d * 3

        t = Root()
        t.deliver 5
        .then "bar", (n, v) ->
          n.set 'existant2', 'foo'
          v
        .all "foo", [direct]
        .finally (c, res) ->
          chai.expect(c.get('existant2')).to.equal 'foo'
          chai.expect(res).to.be.an 'array'
          chai.expect(res).to.eql [ 15 ]
          done()
          
  
  describe 'section example', ->
    
    testSections = (failedComponent, done) ->
      component = (n,d) ->
        n.tree 'component'
        .deliver()
        .then failedComponent
        .else 'subcomponent-optional', ->
          true
        .then ->
          true
    
      post = (n,d) ->
        n.tree 'post'
        .deliver()
        .then (n) ->
          item = n.getItem (item) ->
            item
          n.eatItem item
          item
        .then component
        .else (n) ->
          n.abort('component required')
        .then failedComponent
        .else 'component-optional', ->
          true
        .all [component, failedComponent]
        .else 'components-optional', ->
          true
        .some [component, failedComponent]
            
      section = (n,d) ->
        n.tree 'section'
        .deliver()
        .then post
        .then ->
          'section'
    
      layout = (n, sections) ->
        n.tree 'layout'
        .deliver()
        .contest sections
          , (n, results) -> # scoring
            return results[0]
          , (n, chosen) -> # until
            return false if n.availableItems().length
            true

      Root()
      .deliver
        items: [
            id: 1
          ,
            id: 2
          ,
            id: 3
        ]
      .then ->
        [section]
      .then layout
      .finally (n, results) ->
        chai.expect(results.length).to.equal 3
        done()

    it 'should work w/ thrown failedComponent', (done) ->
      
      failedComponent = (n,d) ->
        n.tree 'failedComponent'
        .deliver()
        .then (n) ->
          throw 'failedComponent thrown'
      
      testSections failedComponent, done
    
    it 'should work w/ aborted failedComponent', (done) ->
      
      failedComponent = (n,d) ->
        n.tree 'failedComponent'
        .deliver()
        .then (n) ->
          n.abort('failedComponent aborted')
      
      testSections failedComponent, done
      
      



