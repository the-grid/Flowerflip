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
      thenable = t.then (c, p) ->
        c.attributes.items = p.items
        p
      layout thenable
      .always (c, d) ->
        clean = d.replace /\n/g, ''
        chai.expect(clean).to.equal '<section class="red directed"><article class="post"><p>Foo</p></article><article class="post"><h1>Bar</h1></article></section>'
        process.nextTick ->
          console.error t.tree.toDOT()
          done()
