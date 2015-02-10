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
      layout = require './fixtures/helloworld/index'
      t.deliver page
      thenable = t.then (c, p) ->
        c.attributes.items = p.items
        p
      layout thenable
      .always (c, d) ->
        console.log c.get 'color'
        console.log c.get 'layout'
        console.log c.get 'items'
        if d instanceof Error
          console.log ''+c, d.stack
          return
        console.log ''+c, d
