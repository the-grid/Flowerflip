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
      .always (path, val) ->
        console.log path
        # The real resolved path (always hasn't resolved yet)
        chai.expect(t.path).to.eql ['w-image', 'portrait', 'faces']
        # Current path (if this resolves)
        chai.expect(path).to.eql ['w-image', 'portrait', 'faces', 'always']
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
