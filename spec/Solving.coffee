chai = require 'chai' unless chai
Root = require '../lib/Root'

describe 'Solving a layout problem', ->
  describe 'with the Hello World layout', ->
    it 'should solve a single-item site', (done) ->
      page =
        config:
          color: 'red'
          layout: 'directed'
        items: [
          id: 'foo'
          content: [
            type: 'text'
            text: 'Foo'
          ]
        ]
      t = Root()
      layout = require '../examples/helloworld/index'
      t.deliver page
      layout t
      .finally (c, d) ->
        chai.expect(d).to.be.a 'string'
        clean = d.replace /\n/g, ''
        chai.expect(clean).to.equal '<section class="red directed"><article class="post left"><p>Foo</p></article></section>'
        chai.expect(c.namedPath()).to.eql [
          'color'
          'user'
          'red'
          'layout'
          'user'
          'directed'
          'sections'
        ]
        return done()
    it 'should solve a two-item site', (done) ->
      page =
        config:
          color: 'red'
          layout: 'directed'
        items: [
          id: 'foo'
          content: [
            type: 'text'
            text: 'Foo'
          ]
        ,
          id: 'bar'
          content: [
            type: 'h1'
            text: 'Bar'
          ]
        ]
      t = Root()
      layout = require '../examples/helloworld/index'
      t.deliver page
      layout t
      .finally (c, d) ->
        #console.error t.toDOT()
        chai.expect(d).to.be.a 'string'
        chai.expect(c.namedPath()).to.eql [
          'color'
          'user'
          'red'
          'layout'
          'user'
          'directed'
          'sections'
        ]
        clean = d.replace /\n/g, ''
        chai.expect(clean).to.equal '<section class="red directed"><article class="post left"><p>Foo</p></article><article class="post right"><h1>Bar</h1></article></section>'
        return done()

  describe 'with invalid page config', ->
    it 'should produce an Error in finally', (done) ->
      page =
        items: [
          id: 'foo'
          content: [
            type: 'invalid22'
            text: 'Foo'
          ]
        ]
      t = Root()
      layout = require '../examples/helloworld/index'
      t.deliver page
      layout t
      .finally (c, d) ->
        chai.expect(d).to.be.instanceof Error
        chai.expect(c.namedPath()).to.eql [
          'color'
          'derived'
          'blue'
          'layout'
          'derived'
          'simple'
          ]
        return done()

  describe 'with invalid page config', ->
    it 'should produce an Error in else', (done) ->
      page =
        items: [
          id: 'foo'
          content: [
            type: 'invalid22'
            text: 'Foo'
          ]
        ]
      t = Root()
      layout = require '../examples/helloworld/index'
      t.deliver page
      layout t
      .else (c, d) ->
        chai.expect(d).to.be.instanceof Error
        return done()

  describe 'with invalid page content', ->
    it 'should produce an Error in finally', (done) ->
      page =
        config:
          color: 'red'
          layout: 'directed'
        items: [
          id: 'foo'
          content: [
            type: 'invalid22'
            text: 'Foo'
          ]
        ]
      t = Root()
      layout = require '../examples/helloworld/index'
      t.deliver page
      layout t
      .finally (c, d) ->
        chai.expect(d).to.be.instanceof Error
        chai.expect(c.namedPath()).to.eql [
          'color'
          'user'
          'red'
          'layout'
          'user'
          'directed'
          ]
        return done()

  describe 'with invalid page content', ->
    it 'should produce an Error in else', (done) ->
      page =
        config:
          color: 'red'
          layout: 'directed'
        items: [
          id: 'foo'
          content: [
            type: 'invalid22'
            text: 'Foo'
          ]
        ]
      t = Root()
      layout = require '../examples/helloworld/index'
      t.deliver page
      layout t
      .else (c, d) ->
        chai.expect(d).to.be.instanceof Error
        return done()

