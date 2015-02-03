chai = require 'chai' unless chai
Thenable = require '../lib/thenable'

describe 'Thenable named promises', ->
  describe 'on resolved promise', ->
    it 'should call the "then" callback defined before delivery', (done) ->
      t = new Thenable
      t.then 'foo', (path, val) ->
        chai.expect(val).to.equal 'bar'
        chai.expect(path).to.eql ['foo']
        done()
      t.deliver 'bar'
    it 'should call the "then" callback defined after delivery', (done) ->
      t = new Thenable
      t.deliver 'bar'
      t.then 'baz', (path, val) ->
        chai.expect(val).to.equal 'bar'
        chai.expect(path).to.eql ['baz']
        done()
  describe 'on failed promise', ->
    it 'should call the "else" callback', (done) ->
      t = new Thenable
      t.then 'foo', (path, val) ->
        throw new Error 'Failboat'
      .else 'bar', (path, e) ->
        chai.expect(path).to.eql ['bar']
        chai.expect(e.message).to.equal 'Failboat'
        done()
      t.deliver 'Hello'
  describe 'with anonymous thenable', ->
    it 'should resolve', (done) ->
      t = new Thenable
      t.then ->
        throw new Error 'Error'
      .else ->
        {}
      .else ->
        {}
      .then ->
        {}
      .always ->
        chai.expect(t.path).to.eql ['else', 'then']
        done()
        true
      t.deliver 'foo'
      
  describe 'with all & return values', ->
    it 'should resolve', (done) ->
      t = new Thenable
      t.tree 'start', ->
        {}
      .then 'yep-1', ->
        return 1
      .then 'yep-2', ->
        return 2
      .then 'yep-3', ->
        return 3
      .all 'all-yep', (choice, data) ->
        chai.expect(data).to.eql [1,2,3]
      .then 'nope-1', (choice, data) ->
        e = new Error ""
        e.data =
          yeps: data
          nopes: 1
        throw e
      .then 'nope-2', ->
        e = new Error ""
        e.data = 2
        throw e
      .then 'nope-3', ->
        e = new Error ""
        e.data = 3
        throw e
      .all 'all-nope', ->
        {}
      .else 'all-nope-else', (choice, e) ->
        chai.expect(e.data).to.eql
          yeps: [1,2,3]
          nopes: 1
        return e.data
      .always (choice, data) ->
        chai.expect(t.path).to.eql ['start', 'yep-1', 'yep-2', 'yep-3', 'all-yep', 'all-nope-else']
        chai.expect(data).to.eql
          yeps: [1,2,3]
          nopes: 1
        done()
        true
      t.deliver 'foo'

  describe 'with looping thenable feeding the same tree', ->
    it 'should resolve', (done) ->
      max = 3
      loops = 0
      looper = (decisionTree) ->
        loops++
        t = new Thenable decisionTree
        t.then 'one', (choice,data) ->
          if t.path.indexOf('one') isnt -1
            throw new Error 'We already did this'
          {}
        .else 'two', ->
          if t.path.indexOf('two') isnt -1
            throw new Error 'We already did this'
          {}
        .else 'three', ->
          if t.path.indexOf('three') isnt -1
            throw new Error 'We already did this'
          {}
        .then (path, val) ->
          if loops >= max
            throw new Error 'all done'
          looper t.decisionTree
          {}
        .else (path, err) ->
          chai.expect(t.path).to.eql ['one', 'then', 'two', 'then', 'three']
          console.log t.decisionTree
          done()
        t.deliver 'foo'
      do looper

  describe 'with contested static node branching', ->
    it 'should resolve', (done) ->
      t = new Thenable
      t.tree 'start', (node, data) ->
        node.branch 'option-1', ->
          {}
        .then 'option-1-sub', ->
          {}
        node.branch 'option-2', ->
          {}
        .then 'option-2-sub', ->
          {}
        node.contest (choices) ->
          return choices[choices.length-1]
        .deliver(true) # needed?
      .then 'after', ->
        return true
      .always ->
        
        chai.expect(t.path).to.eql ['start', 'option-2', 'option-2-sub', 'after']
        
        done()
        true
      t.deliver 'foo'
  
  describe 'with contested dynamic node branching', ->
    it 'should resolve', (done) ->
      t = new Thenable
        # API method to choose a tied contest
        decideTie: (choices) ->
          return choices[0]
      t.tree 'start', (node, data) ->
        for thing in ['foo','bar','tum']
          node.branch thing, ->
            {}
        node.contest() # missing!
        .deliver(true) # needed?
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
        process.nextTick ->
          try
            console.error t.toDOT()
          catch e
            console.log e
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
