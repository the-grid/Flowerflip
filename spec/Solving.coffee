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
        ,
          id: 'bar'
          content: [
            type: 'h1'
            text: 'Bar'
          ]
        ]
      t = Root()
      layout = require './fixtures/helloworld/index'
      t.deliver page
      layout t
      .finally (c, d) ->
        chai.expect(c.namedPath()).to.eql [
          'color'
          'user'
          'red'
          'layout'
          'user'
          'directed'
          'sections'
        ]
        chai.expect(d).to.be.a 'string'
        clean = d.replace /\n/g, ''
        chai.expect(clean).to.equal '<section class="red directed"><article class="post"><p>Foo</p></article><article class="post"><h1>Bar</h1></article></section>'
        return done()
        process.nextTick ->
          console.error t.tree.toDOT()
          done()
