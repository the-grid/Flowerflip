chai = require 'chai' unless chai
Thenable = require '../lib/thenable'

describe 'Thenable named promises', ->
  describe 'on resolved promise', ->
    it 'should call the "then" callback defined before delivery', (done) ->
      t = new Thenable
      t.then 'foo', (choice, val) ->
        chai.expect(val).to.equal 'bar'
        chai.expect(choice.path).to.eql ['root', 'foo']
        done()
      t.deliver 'bar'
    it 'should call the "then" callback defined after delivery', (done) ->
      t = new Thenable
      t.deliver 'bar'
      t.then 'baz', (choice, val) ->
        chai.expect(val).to.equal 'bar'
        chai.expect(choice.path).to.eql ['root', 'baz']
        done()
  describe 'on failed promise', ->
    it 'should call the "else" callback', (done) ->
      t = new Thenable
      t.then 'foo', (choice, val) ->
        throw new Error 'Failboat'
      .else 'bar', (choice, e) ->
        chai.expect(choice.path).to.eql ['root', 'foo', 'bar']
        chai.expect(e.message).to.equal 'Failboat'
        process.nextTick ->
          chai.expect(choice.namedPath()).to.eql ['bar']
          done()
      t.deliver 'Hello'
  describe 'with anonymous thenable', ->
    it 'should resolve', (done) ->
      t = new Thenable
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
      
  describe 'with all & return values', ->
    it 'should resolve', (done) ->
      t = new Thenable

      y1 = (data) ->
        th = new Thenable
        th.deliver data
        pr = th.then 'yep-1', ->
          1
        pr

      y2 = (data) ->
        th = new Thenable
        th.deliver data
        .then 'yep-2', ->
          2
      y3 = (data) ->
        th = new Thenable
        th.deliver data
        .then 'yep-3', ->
          3

      n1 = ( data) ->
        th = new Thenable
        th.deliver data
        .then 'nope-1', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 1
          throw e
      n2 = (data) ->
        new Thenable
        .deliver data
        .then 'nope-2', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 2
          e
      n3 = (data) ->
        new Thenable
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
      .then 'all-nope', ->
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

  describe 'with some & return values', ->
    it 'should resolve', (done) ->
      t = new Thenable

      y1 = (data) ->
        new Thenable()
        .deliver data
        .then 'yep-1', ->
          1
      y2 = (data) ->
        th = new Thenable()
        th.deliver data
        .then 'yep-2', ->
          throw new Error 'Foo'
      y3 = (data) ->
        new Thenable()
        .deliver data
        .then 'yep-3', (path, data) ->
          3

      n1 = ( data) ->
        new Thenable()
        .deliver data
        .then 'nope-1', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 1
          throw e
      n2 = (data) ->
        new Thenable()
        .deliver data
        .then 'nope-2', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 2
          throw e
        .all 'still nope', (path, data) ->
          throw new Error ""
      n3 = (data) ->
        new Thenable()
        .deliver data
        .then 'nope-3', (path, data) ->
          e = new Error ""
          e.data =
            yeps: data
            nopes: 3
          throw e

      t.tree 'start', ->
        {}
      .some [y1, y2, y3]
      .then 'some-yep', (choice, data) ->
        chai.expect(data).to.eql [1,3]
        data
      .else (choice, data) ->
        throw new Error 'foo'
      .some [n1, n2, n3]
      .then 'some-nope', ->
        {}
      .else 'some-nope-else', (choice, e) ->
        chai.expect(e.data).to.eql
          yeps: [1,3]
          nopes: 3
        return e.data
      .always (choice, data) ->
        process.nextTick ->
          chai.expect(t.namedPath).to.eql ['start', 'some-yep', 'some-nope-else']
          chai.expect(data).to.eql
            yeps: [1,3]
            nopes: 3
          done()
        true
  describe 'with looping thenable feeding the same tree', ->
    it 'should resolve', (done) ->
      max = 3
      loops = 0
      looper = (decisionTree) ->
        loops++
        t = new Thenable decisionTree
        t.then 'one', (choice,data) ->
          if t.namedPath.indexOf('one') isnt -1
            throw new Error 'We already did this'
          {}
        .else 'two', ->
          if t.namedPath.indexOf('two') isnt -1
            throw new Error 'We already did this'
          {}
        .else 'three', ->
          if t.namedPath.indexOf('three') isnt -1
            throw new Error 'We already did this'
          {}
        .then (path, val) ->
          if loops >= max
            throw new Error 'all done'
          looper t.decisionTree
          {}
        .else (path, err) ->
          chai.expect(t.namedPath).to.eql ['one', 'two', 'three']
          done()
        t.deliver 'foo'
      do looper

  describe.skip 'with contested static node branching', ->
    it 'should resolve', (done) ->
      t = new Thenable
      t.tree 'start', (node, data) ->
        t.branch 'option-1', ->
          {}
        .then 'option-1-sub', ->
          {}
        t.branch 'option-2', ->
          {}
        .then 'option-2-sub', ->
          {}
        t.contest (choices) ->
          return choices[choices.length-1]
      .then 'after', ->
        return true
      .always ->
        chai.expect(t.path).to.eql ['start', 'option-2', 'option-2-sub', 'after']
        
        done()
        true
      t.deliver 'foo'
  
  describe.skip 'with contested dynamic node branching', ->
    it 'should resolve', (done) ->
      t = new Thenable null,
        # API method to choose a tied contest
        decideTie: (choices) ->
          return choices[0]
      t.tree 'start', (node, data) ->
        for thing in ['foo','bar','tum']
          t.branch thing, ->
            {}
      .contest null
      .then 'after', ->
        return true
      .always ->
        tree = t.decisionTree
        
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
      t = new Thenable
      t.tree ->
        true
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
      .always (path, val) ->
        # The real resolved path (always hasn't resolved yet)
        chai.expect(t.path).to.eql ['w-image', 'portrait', 'small']
        # Current path (if this resolves)
        chai.expect(path).to.eql ['w-image', 'portrait', 'small', 'always']
        done()
    it 'should produce the expected path also when there are sub-trees', (done) ->
      t = new Thenable
      t.tree ->
        true
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
      .then 'faces', ->
        t2 = new Thenable
        t2.tree 'face-detection', ->
          {}
        .then 'match-people', ->
          {}
        .then 'find-friends', ->
          throw new Error 'Trying hard'
        .else 'no-friends', (path, faces) ->
          {}
      .then 'cropping', ->
        {}
      .always (path, val) ->
        # The real resolved path (always hasn't resolved yet)
        chai.expect(t.path).to.eql ['w-image', 'portrait', 'faces', 'cropping']
        # Current path (if this resolves)
        chai.expect(path).to.eql ['w-image', 'portrait', 'faces', 'cropping', 'always']
        done()
        true
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
