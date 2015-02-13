chai = require 'chai' unless chai
Root = require '../lib/Root'

describe 'Thenable named promises', ->
  describe 'on resolved promise', ->
    it 'should call the "then" callback defined before delivery', (done) ->
      t = Root()
      t.then 'foo', (choice, val) ->
        chai.expect(val).to.equal 'bar'
        chai.expect(choice.path).to.eql ['root', 'foo']
        done()
      t.deliver 'bar'
    it 'should call the "then" callback defined after delivery', (done) ->
      t = Root()
      t.deliver 'bar'
      t.then 'baz', (choice, val) ->
        chai.expect(val).to.equal 'bar'
        chai.expect(choice.path).to.eql ['root', 'baz']
        done()
  describe 'on failed promise', ->
    it 'should call the "else" callback', (done) ->
      t = Root()
      t.then 'foo', (choice, val) ->
        throw new Error 'Failboat'
      .else 'bar', (choice, e) ->
        chai.expect(choice.path).to.eql ['root', 'foo', 'bar']
        chai.expect(e.message).to.equal 'Failboat'
        chai.expect(choice.namedPath()).to.eql []
        chai.expect(choice.namedPath(true)).to.eql ['bar']
        done()
      t.deliver 'Hello'
  describe 'on failed precondition in promise', ->
    it 'should call the "else" callback with AssertionError', (done) ->
      t = Root()
      t.then 'foo', (choice, val) ->
        choice.expect(val).to.equal 'World'
      .else 'bar', (choice, e) ->
        chai.expect(choice.path).to.eql ['root', 'foo', 'bar']
        chai.expect(e.message).to.equal "expected 'Hello' to equal 'World'"
        chai.expect(choice.namedPath()).to.eql []
        chai.expect(choice.namedPath(true)).to.eql ['bar']
        done()
      t.deliver 'Hello'
  describe 'with anonymous thenable', ->
  describe 'on failed precondition in promise', ->
    it 'should call the "else" callback with throwVal', (done) ->
      t = Root()
      t.then 'foo', (choice, val) ->
        choice.expect(val, val).to.equal 'World'
      .else 'bar', (choice, e) ->
        chai.expect(choice.path).to.eql ['root', 'foo', 'bar']
        chai.expect(e).to.equal 'Hello'
        chai.expect(choice.namedPath()).to.eql []
        chai.expect(choice.namedPath(true)).to.eql ['bar']
        done()
      t.deliver 'Hello'
  describe 'with anonymous thenable', ->
    it 'should resolve', (done) ->
      t = Root()
      t.then ->
        # Executed, failing
        throw new Error 'Error'
      .else ->
        # Executed
        {}
      .else ->
        # Ignored
        {}
      .then ->
        # Executed
        'bar'
      .always (choice, d) ->
        # Executed
        chai.expect(choice.namedPath()).to.eql []
        chai.expect(choice.fulfilledPath()).to.eql ['else', 'then_1']
        chai.expect(choice.path).to.eql ['root', 'then', 'else', 'then_1', 'always']
        chai.expect(d).to.equal d
        done()
        true
      t.deliver 'foo'
    it 'should throw error if there is no "else" subscriber', (done) ->
      err = null
      try
        t = Root()
        t.finally (c, d) ->
          throw new Error "Failed here #{d}"
        t.deliver 'foo'
      catch e
        err = e
      chai.expect(err).to.be.an.instanceOf Error
      chai.expect(err.message).to.equal 'Failed here foo'
      done()
      
  describe 'with all & return values', ->
    it 'should resolve', (done) ->
      t = Root()

      y1 = (c, data) ->
        th = Root()
        th.deliver data
        pr = th.then 'yep-1', ->
          1
        pr

      y2 = (c, data) ->
        th = Root()
        th.deliver data
        .then 'yep-2', ->
          2
      y3 = (c, data) ->
        th = Root()
        th.deliver data
        .then 'yep-3', ->
          3

      n1 = (c, data) ->
        th = Root()
        th.deliver data
        .then 'nope-1', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 1
          throw e
      n2 = (c, data) ->
        Root()
        .deliver data
        .then 'nope-2', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 2
          e
      n3 = (c, data) ->
        Root()
        .deliver data
        .then 'nope-3', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 3
          throw e
      t.deliver {}
      .all [y1, y2, y3]
      .then 'all-yep', (choice, data) ->
        chai.expect(data).to.eql [1,2,3]
        data
      .all [n1, n2, n3]
      .then 'all-nope', (choice, data) ->
        {}
      .else 'all-nope-else', (choice, e) ->
        chai.expect(e.data).to.eql
          yeps: [1,2,3]
          nopes: 1
        return e.data
      .always (choice, data) ->
        chai.expect(choice.namedPath()).to.eql ['all-yep', 'all-nope-else']
        chai.expect(data).to.eql
          yeps: [1,2,3]
          nopes: 1
        done()
        true

  describe 'with all & branches', ->
    it 'should resolve with result per branch', (done) ->
      brancher = (orig, data) ->
        subtree = orig.tree 'calc'
        subtree.deliver data
        t = subtree.then (choice) ->
          choice.branch 'doubled', (c, d) ->
            d * 2
          choice.branch 'squared', (c, d) ->
            d * d
        t
      direct = (orig, data) ->
        subtree = orig.tree 'directcalc'
        subtree.deliver data
        t = subtree.then 'tripled', (c, d) ->
          d * 3

      t = Root()
      t.deliver 5
      .all [brancher, direct]
      .finally (c, res) ->
        chai.expect(res).to.be.an 'array'
        chai.expect(res).to.eql [
          [10, 25]
          15
        ]
        done()

  describe 'with race & return values', ->
    it 'should resolve', (done) ->
      multiply = (multiplier, orig, data) ->
        tree = orig.tree 'a'
        tree.deliver data
        tree.then (c, d) ->
          d * multiplier
      t = Root()
      t.deliver 5
      .race [
        multiply.bind @, 2
        multiply.bind @, 3
      ]
      .then (c, res) ->
        chai.expect(res).to.equal 10
        done()

  describe 'with race & abort', ->
    it 'should resolve', (done) ->
      multiply = (multiplier, orig, data) ->
        tree = orig.tree 'a'
        tree.deliver data
        tree.then (c, d) ->
          d * multiplier
          c.abort "I would've returned #{d*multiplier}, but chose not to"
      t = Root()
      t.deliver 5
      .race [
        multiply.bind @, 2
        multiply.bind @, 3
      ]
      .finally (c, res) ->
        chai.expect(res).to.be.instanceof Error
        done()
    it 'should resolve with value if given', (done) ->
      multiply = (multiplier, orig, data) ->
        tree = orig.tree 'a'
        tree.deliver data
        tree.then (c, d) ->
          d * multiplier
          c.abort "I would've returned #{d*multiplier}, but chose not to", multiplier
      t = Root()
      t.deliver 5
      .race [
        multiply.bind @, 2
        multiply.bind @, 3
      ]
      .finally (c, res) ->
        chai.expect(res).to.equal 3
        done()

  describe 'with maybe & return values', ->
    it 'should resolve', (done) ->
      multiply = (multiplier, orig, data) ->
        tree = orig.tree 'a'
        tree.deliver data
        tree.then (c, d) ->
          d * multiplier
      t = Root()
      t.deliver 5
      .maybe [
        multiply.bind @, 2
        multiply.bind @, 3
      ]
      .finally (c, res) ->
        chai.expect(res).to.eql [10, 15]
        done()

  describe 'with maybe & abort', ->
    it 'should resolve', (done) ->
      multiply = (multiplier, orig, data) ->
        tree = orig.tree 'a'
        tree.deliver data
        tree.then (c, d) ->
          d * multiplier
          c.abort "I would've returned #{d*multiplier}, but chose not to"
      t = Root()
      t.deliver 5
      .maybe [
        multiply.bind @, 2
        multiply.bind @, 3
      ]
      .else (c, res) ->
        chai.expect(res).to.be.a 'number'
        chai.expect(res).to.equal 5
        done()

  describe 'with some & return values', ->
    it 'should resolve', (done) ->
      t = Root()

      y1 = (c, data) ->
        Root()
        .deliver data
        .then 'yep-1', ->
          1
      y2 = (c, data) ->
        th = Root()
        th.deliver data
        .then 'yep-2', ->
          throw new Error 'Foo'
      y3 = (c, data) ->
        Root()
        .deliver data
        .then 'yep-3', (path, data) ->
          3

      n1 = (c, data) ->
        Root()
        .deliver data
        .then 'nope-1', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 1
          throw e
      n2 = (c, data) ->
        Root()
        .deliver data
        .then 'nope-2', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 2
          throw e
        .else 'still nope', (path, data) ->
          throw new Error "still nope"
      n3 = (c, data) ->
        Root()
        .deliver data
        .then 'nope-3', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 3
          throw e

      t.deliver {}
      .some [y1, y2, y3]
      .then 'some-yep', (choice, data) ->
        chai.expect(data).to.be.an 'array'
        chai.expect(data[0]).to.equal 1
        chai.expect(data[2]).to.equal 3
        data
      .else (choice, data) ->
        throw new Error 'foo'
      .some [n1, n2, n3]
      .then 'some-nope', ->
        {}
      .else 'some-nope-else', (choice, e) ->
        chai.expect(e.data).to.be.an 'object'
        chai.expect(e.data.yeps).to.be.an 'array'
        chai.expect(e.data.yeps[0]).to.equal 1
        chai.expect(e.data.yeps[2]).to.equal 3
        chai.expect(e.data.nopes).to.equal 3
        return e.data
      .always (choice, data) ->
        chai.expect(choice.namedPath()).to.eql ['some-yep', 'some-nope-else']
        chai.expect(data.yeps).to.be.an 'array'
        chai.expect(data.yeps[0]).to.equal 1
        chai.expect(data.yeps[2]).to.equal 3
        chai.expect(data.nopes).to.equal 3
        done()

  describe 'with contest & simple scoring', ->
    it 'should resolve', (done) ->
      multiply = (multiplier, orig, data) ->
        tree = orig.tree 'a'
        tree.deliver data
        tree.then "#{multiplier}", (c, d) ->
          d * multiplier
      t = Root()
      t.deliver 5
      .contest [
        multiply.bind @, 2
        multiply.bind @, 3
      ], (c, results) ->
        paths = results.map (r) -> r.path
        idx = paths.indexOf 'root-3-then'
        results[idx]
      .then (c, res) ->
        chai.expect(res).to.eql [15]
        done()

  describe.skip 'with contested static node branching', ->
    it 'should resolve', (done) ->
      t = Root()
      t.then 'start', (node, data) ->
        node.branch 'option-1', ->
          {}
        node.branch 'option-2', ->
          {}
        true
      .contest (choices) ->
        return choices[choices.length-1]
      .then 'after', (choice) ->
        return true
      .then (choice, val) ->
        chai.expect(choice.namedPath()).to.eql ['option-2', 'option-2-sub', 'after']
        done()
      t.deliver 'foo'
  
  describe.skip 'with contested dynamic node branching', ->
    it 'should resolve', (done) ->
      t = Root
        # API method to choose a tied contest
        decideTie: (choices) ->
          return choices[0]
      t.deliver 'foo'
      t.then 'start', (node, data) ->
        for thing in ['foo','bar','tum']
          t.branch thing, ->
            {}
      .contest null
      .then 'after', ->
        return true
      .always ->
        chai.expect(t.path).to.eql ['start', 'foo', 'after']
        
        firstChoice = tree.getChoice(t.path[0])
        
        # brute method        
        fromStart = tree.decisions.filter (d) -> d.from is t.getId 'start'
        fromStartNames = fromStart.map (d) -> d.name
        chai.expect(fromStart).to.eql ['foo', 'bar', 'tum']
        fromStartTypes = fromStart.map (d) -> d.type
        chai.expect(fromStartTypes).to.eql ['fulfilled', 'ignored', 'ignored']
        
        # sugar
        fromStart = tree.decisionNamesAt 'start'
        chai.expect(fromStart).to.eql ['foo', 'bar', 'tum']
        
        done()
        true
      t.deliver 'foo'

  describe 'handling a multi-dimensional template branch', ->
    it 'should produce the expected path', (done) ->
      t = Root()
      t.deliver true
      .then 'w-image', ->
        return {}
      .else 'wo-image', ->
        return {}
      .then 'landscape', ->
        throw new Error 'Not landscape'
      .else 'portrait', ->
        return {}
      .else 'square', ->
        throw new Error 'Not square'
      .then 'large', ->
        throw new Error 'Too small'
      .else 'small', ->
        return {}
      .always (choice, val) ->
        # The real resolved path (always hasn't resolved yet)
        chai.expect(choice.namedPath()).to.eql ['w-image', 'portrait', 'small']
        done()
    it 'should produce the expected path also when there are sub-trees', (done) ->
      t = Root()
      t.deliver true
      .then 'w-image', ->
        return {}
      .else 'wo-image', ->
        return {}
      .then 'landscape', ->
        throw new Error 'Not landscape'
      .else 'portrait', ->
        return {}
      .else 'square', ->
        throw new Error 'Not square'
      .then 'faces', (choice, data) ->
        t2 = Root()
        t2.deliver data
        t2.then 'face-detection', ->
          {}
        .then 'match-people', ->
          {}
        .then 'find-friends', ->
          throw new Error 'Trying hard'
        .else 'no-friends', (path, faces) ->
          {}
      .always 'cropping', ->
        {}
      .always (choice, val) ->
        # The real resolved path (always hasn't resolved yet)
        chai.expect(choice.namedPath()).to.eql ['w-image', 'portrait', 'faces', 'cropping']
        done()
        true

  describe 'all() with no tasks', ->
    it 'should give error', (done) ->
      t = Root()
      t.deliver true
      .then 'foo', ->
        return false
      .all 'empty-all', []
      .finally (c, val) ->
        chai.expect(val).to.be.instanceof Error
        chai.expect(val.message).to.include 'No tasks'
        done()

  describe 'getting attribute in consecutive choice', ->
    it 'should return value', (done) ->
      t = Root()
      t.then 'foo', (choice, val) ->
        choice.set 'val1', 'baz'
        null
      .finally 'bar', (choice, val) ->
        chai.expect(val).to.be.a 'null'
        chai.expect(choice.get('val1')).to.equal 'baz'
        done()
      t.deliver 'inpt1'
  describe 'getting non-existant attribute in consecutive choice', ->
    it 'should return value', (done) ->
      t = Root()
      t.then 'foo', (choice, val) ->
        choice.set 'val1', 'baz'
        null
      .finally 'bar', (choice, val) ->
        chai.expect(val).to.be.a 'null'
        chai.expect(choice.get('non-existant2')).to.equal null
        done()
      t.deliver 'inpt2'

###
articleComponent = (ctx, item, promise) ->
  block = ctx.getBlock (b) ->
    ctx.expect(b.type is 'article')
  promise.reject() unless block

  ctx.branch 'w-image', ->
    ctx.expect b.cover?, 'Cover needed for with image'
    return ->
  .else 'wo-image', ->
    # No-op
    return ->
  .then 'landscape', ->
    ctx.expect (b.cover.orientation is 'landscape'), 'Image needs to be landscape'
    return ->
  .else 'portrait', ->
    # No-op
    return ->
  .then ->
    promise.deliver
      path: ctx.path
      gss: ''
      css: ''

repostSection =
  evaluate: (ctx, promise) ->
    return ->
  simulate: ->

describe 'Thenable repost section', ->
  it 'should resolve a single repost with image', (done) ->
    context =
      items: [
        id: 'repost'
        content: [
          type: 'article'
          cover:
            src: 'image.png'
        ]
      ]

    Thenable.evaluate repostSection, context
    .then (result) ->
      console.log result
      done()
###
