chai = require 'chai' unless chai
poly = require '../lib/poly'

isNode = typeof process isnt 'undefined' and process.execPath and process.execPath.match /node|iojs/
itSkipNode = if isNode then it.skip else it

describe 'Poly integration', ->
  describe 'calling register()', ->
    itSkipNode 'should set window.polySolvePage', (done) ->
      window.polySolvePage = null
      layout = require '../examples/helloworld/index'
      poly.register layout
      chai.expect(window.polySolvePage).to.be.a 'function'
      done()

  describe 'using HelloWorld filter', ->
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
      layout = require '../examples/helloworld/index'
      poly.register layout
      solvePage = if isNode then poly.polySolvePage else window.polySolvePage
      solvePage page, {}, (err, result, tree) ->
        chai.expect(err).to.be.a 'null'
        chai.expect(result).to.be.a 'string'
        chai.expect(result).to.include '<section class'
        return done()

  describe 'with invalid page config', ->
    it 'should callback with Error', (done) ->
      page =
        items: [
          id: 'foo'
          content: [
            type: 'invalid22'
            text: 'Foo'
          ]
        ]
      layout = require '../examples/helloworld/index'
      poly.register layout
      solvePage = if isNode then poly.polySolvePage else window.polySolvePage
      solvePage page, {}, (err, result, tree) ->
        chai.expect(err).to.be.instanceof Error
        return done()


