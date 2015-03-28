chai = require 'chai' unless chai
Choice = require '../lib/Choice'
Root = require '../lib/Root'

describe 'Subtrees', ->

  describe 'using subtree with continue', ->
    it 'should generate good path', (done) ->
      treeComposition = (c, d) ->
        sub = c.continue 'subtree_c'
        sub.deliver d
        sub.then 'subthen0', (c, d) ->
          d
        .then 'subthen1', (c, d) ->
          d
      t = Root()
      t.deliver 10
      .then 'then0', (c, d) ->
        d
      .all 'allin', [
        treeComposition.bind @
        treeComposition.bind @
      ]
      .then 'then1', (c, d) ->
        d
      .finally (c, d) ->
        exp = {
          path: [
             'then0',
             'allin',
             'subtree_c',
             'subthen0',
             'subthen1',
             'then1']
          children: []
        }
        chai.expect(c.toSong()).to.eql exp
        done()

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

  describe 'contest where subtrees branch and eat', ->
    consumptionBrancher = (c, d) ->
      c.tree 'consumption'
      .deliver d
      .then (choice, data) ->
        choice.availableItems().forEach (i) ->
          choice.branch "#{i.id}", (b, d) ->
            b.set 'item', i
      .then (choice, data) ->
        item = choice.get 'item'
        choice.eatItem item
    sectionBrancher = (c, d) ->
      c.tree 'section'
      .deliver d
      .then (choice, data) ->
        ['a', 'b', 'c', 'd'].forEach (letter) ->
          choice.branch letter, (b, d) ->
            b.continue 'sub'
            .deliver d
            .then (c, d) ->
              ['z', 'x', 'v', 'r'].forEach (letter) ->
                choice.branch letter, (b, d) ->
                  d
      .all [consumptionBrancher]
    it 'should only eat the chosen branch', (done) ->
      t = Root()
      t.deliver
        items: [
          id: 1
        ,
          id: 2
        ,
          id: 3
        ]
      .contest [
        sectionBrancher
      ]
      .finally (c, d) ->
        available = c.availableItems().map (i) -> i.id
        chai.expect(available).to.eql [2, 3]
        done()
