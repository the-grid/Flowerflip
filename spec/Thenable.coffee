chai = require 'chai' unless chai
Root = require '../lib/Root'

describe 'Thenable', ->


  #8888888ba                          88
  #8      "8b                         ""
  #8      ,8P
  #8aaaaaa8P'  ,adPPYYba,  ,adPPYba,  88   ,adPPYba,  ,adPPYba,
  #8""""""8b,  ""     `Y8  I8[    ""  88  a8"     ""  I8[    ""
  #8      `8b  ,adPPPPP88   `"Y8ba,   88  8b           `"Y8ba,
  #8      a8P  88,    ,88  aa    ]8I  88  "8a,   ,aa  aa    ]8I
  #8888888P"   `"8bbdP"Y8  `"YbbdP"'  88   `"Ybbd8"'  `"YbbdP"'

  describe 'basics', ->

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
      it 'should call the "catch" callback', (done) ->
        t = Root()
        t.then 'foo', (choice, val) ->
          throw new Error 'Failboat'
        .catch 'bar', (choice, e) ->
          chai.expect(choice.path).to.eql ['root', 'foo', 'bar']
          chai.expect(e.message).to.equal 'Failboat'
          chai.expect(choice.namedPath()).to.eql []
          chai.expect(choice.namedPath(true)).to.eql ['bar']
          done()
        t.deliver 'Hello'
      it 'should call the "finally" callback', (done) ->
        t = Root()
        t.then 'foo', (choice, val) ->
          throw new Error 'Failboat'
        .finally 'finally_bar', (choice, e) ->
          chai.expect(choice.path).to.eql ['root', 'foo', 'finally_bar']
          chai.expect(e.message).to.equal 'Failboat'
          chai.expect(choice.namedPath()).to.eql []
          chai.expect(choice.namedPath(true)).to.eql ['finally_bar']
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

    describe 'passing arguments', ->
      it 'should produce the expected result', (done) ->
        t = Root()
        t.then (c, d) ->
          # c.source.get('data') is 1, what we delivered to 'root'
          d+1
        .then (c, d) ->
          # c.source.get('data') is 2
          d+1
        .then (c, d) ->
          # c.source.get('data') is 3
          d+1
        .finally (c, d) ->
          # c.source.get('data') is 4
          chai.expect(d).to.equal 4
          done()
        t.deliver 1

    describe 'rethrowing errors', ->
      it 'should resolve', (done) ->
        Root()
        .deliver()
        .then (choice, data) ->
          choice.error()
        .else (choice, err) ->
          throw err
        .else (choice, err) ->
          done()

      it 'should pass on the error', (done) ->
        error = null
        Root()
        .deliver()
        .then (choice, data) ->
          choice.error()
        .else (choice, err) ->
          error = err
          throw err
        .else (choice, err) ->
          chai.expect(err).to.equal error
          done()

      it 'bypass other positive promises', (done) ->
        Root()
        .deliver()
        .then (choice, data) ->
          choice.error()
        .else (choice, err) ->
          throw err
        .then (choice, data) ->
          expect(true).to.equal false
        .else (choice, err) ->
          done()

    describe 'two consecutive negative results in the promise chain', ->
      it 'finally should once be called once', (done) ->
        multiply = (multiplier, orig, data) ->
          tree = orig.tree 'a'
          tree.deliver data
          tree.then (c, d) ->
            c.abort "I would've returned #{d*multiplier}, but chose not to"
        t = Root()
        t.deliver 5
        .maybe [
          multiply.bind @, 2
          multiply.bind @, 3
        ]
        .else (c, res) ->
          res * 2
        .finally (c, res) ->
          done()


  #8888888ba                                                    88
  #8      "8b                                                   88
  #8      ,8P                                                   88
  #8aaaaaa8P'  8b,dPPYba,  ,adPPYYba,  8b,dPPYba,    ,adPPYba,  88,dPPYba,
  #8""""""8b,  88P'   "Y8  ""     `Y8  88P'   `"8a  a8"     ""  88P'    "8a
  #8      `8b  88          ,adPPPPP88  88       88  8b          88       88
  #8      a8P  88          88,    ,88  88       88  "8a,   ,aa  88       88
  #8888888P"   88          `"8bbdP"Y8  88       88   `"Ybbd8"'  88       88

  describe 'branch', ->

    describe 'promise chain within branching', ->
      it 'should execute the promise chain', (done) ->
        multiply = (multiplier, c, data) ->
          tree = c.tree 'a'
          tree.deliver data
          tree.then "#{multiplier}", (c, d) ->
            c.branch 'doubled', (b, data) ->
              data * 2
            c.branch 'tripled', (b, data) ->
              btree = b.continue()
              btree.deliver data
              btree.then 'btreethen', (c, data) ->
                data * 3
        t = Root()
        t.deliver 5
        .contest "contest-multiply", [
          multiply.bind @, 2
          multiply.bind @, 3
        ], (c, results) ->
          paths = results.map (r) -> r.choice.namedPath().join '-'
          idx = paths.indexOf 'a-tripled-btreethen'
          idx = 0 if idx is -1
          results[idx]
        .finally 'end',   (c, res) ->
          chai.expect(res).to.eql [15]
          done()

    describe 'promise chain within branching within continue', ->
      it 'should execute the promise chain', (done) ->
        multiply = (multiplier, c, data) ->
          tree = c.tree 'a'
          tree.deliver data
          tree.then "#{multiplier}", (c, d) ->
            c.continue()
            .deliver()
            .then (choice,d) ->
              choice.branch 'doubled', (b, data) ->
                data * 2
              choice.branch 'tripled', (b, data) ->
                btree = b.continue()
                btree.deliver data
                btree.then 'btreethen', (c, data) ->
                  data * 3
        t = Root()
        t.deliver 5
        .contest "contest-multiply", [
          multiply.bind @, 2
          multiply.bind @, 3
        ], (c, results) ->
          paths = results.map (r) -> r.choice.namedPath().join '-'
          idx = paths.indexOf 'a-tripled-btreethen'
          idx = 0 if idx is -1
          results[idx]
        .finally 'end',   (c, res) ->
          chai.expect(res).to.eql [15]
          done()

    describe.skip 'promise chain after branching', ->
      it 'should walk the promise chain of the branch', (done) ->
        multiply = (multiplier, c, data) ->
          tree = c.tree 'a'
          tree.deliver data
          tree.then "#{multiplier}", (c, d) ->
            c.branch 'doubled', (b, data) ->
              data * 2
            c.branch 'tripled', (b, data) ->
              data
            .then 'bthen0', (c, data) ->
              data
            .then 'bthen1', (c, data) ->
              data * 3
        t = Root()
        t.deliver 5
        .contest "contest-multiply", [
          multiply.bind @, 2
          multiply.bind @, 3
        ], (c, results) ->
          paths = results.map (r) -> r.path
          idx = paths.indexOf 'root-tripled-bthen0-bthen1'
          idx = 0 if idx is -1
          results[idx]
        .finally 'end',   (c, res) ->
          chai.expect(res).to.eql [15]
          done()

    describe 'with a branching thenable', ->
      it 'should run two rounds of execution', (done) ->
        expected = [4, 6]
        t = Root()
        t.then (c, d) ->
          c.branch 'doubled', (b, data) ->
            data * 2
          c.branch 'tripled', (b, data) ->
            data * 3
          d
        .finally (c, d) ->
          exp = expected.shift()
          chai.expect(d).to.equal exp
          done() if expected.length is 0
        t.deliver 2

    describe 'when branching', ->
      it 'the available items of the original choice should be copied to the root choice of the branch', (done) ->
        multiply = (multiplier, c, data) ->
          tree = c.tree 'a'
          tree.deliver data
          tree.then "#{multiplier}", (c, d) ->
            c.branch 'tripled', (b, data) ->
              data is b.availableItems().length
        t = Root()
        t.deliver
          config:
            name: 'test'
            type: 'test'
          items: [
            'item1'
            'item2'
            ]
        .then (c, d) ->
          c.availableItems().length
        .contest "contest-multiply", [
          multiply.bind @, 2
        ], (c, results) ->
          results[0]
        .finally 'enfin-fini', (c, res) ->
          chai.expect(res[0]).to.be.true
          chai.expect(c.availableItems().length).to.equal 2
          done()



    #ad8888ba,                            ad88888ba
   #8"'    `"8b                ,d        d8"     "8b                ,d
  #8'                          88        Y8,                        88
  #8              ,adPPYba,  MM88MMM     `Y8aaaaa,     ,adPPYba,  MM88MMM
  #8      88888  a8P_____88    88          `"""""8b,  a8P_____88    88
  #8,        88  8PP"""""""    88                `8b  8PP"""""""    88
   #8a.    .a88  "8b,   ,aa    88,       Y8a     a8P  "8b,   ,aa    88,
    #"Y88888P"    `"Ybbd8"'    "Y888      "Y88888P"    `"Ybbd8"'    "Y888

  describe 'get & set', ->

    describe 'getting attribute in consecutive choice', ->
      it 'should return value', (done) ->
        Root()
        .deliver 'inpt1'
        .then 'foo', (choice, val) ->
          choice.set 'val1', 'baz'
          null
        .finally 'bar', (choice, val) ->
          chai.expect(val).to.be.a 'null'
          chai.expect(choice.get('val1')).to.equal 'baz'
          done()

    describe 'getting non-existant attribute in consecutive choice', ->
      it 'should return value', (done) ->
        Root()
        .deliver 'inpt2'
        .then 'foo', (choice, val) ->
          choice.set 'val1', 'baz'
          null
        .finally 'bar', (choice, val) ->
          chai.expect(val).to.be.a 'null'
          chai.expect(choice.get('non-existant2')).to.equal null
          done()

    describe 'non-existent attribute lookup in tree', ->
      it 'should return null', (done) ->

        direct = (orig, data) ->
          subtree = orig.tree 'directcalc'
          subtree.deliver data
          t = subtree.then 'tripled', (c, d) ->
            chai.expect(c.get('non-existant1')).to.equal null
            d * 3

        t = Root()
        t.deliver 5
        .all [direct]
        .finally (c, res) ->
          chai.expect(c.get('non-existant2')).to.equal null
          chai.expect(res).to.be.an 'array'
          chai.expect(res).to.eql [
            15
          ]
          done()

    describe 'non-existant attribute lookup in continue tree', ->
      it 'should return null', (done) ->
        direct = (orig, data) ->
          subtree = orig.continue 'directcalc'
          subtree.deliver data
          t = subtree.then 'tripled', (c, d) ->
            chai.expect(c.get('non-existant1')).to.equal null
            d * 3

        t = Root()
        t.deliver 5
        .all [direct]
        .finally (c, res) ->
          chai.expect(c.get('non-existant2')).to.equal null
          chai.expect(res).to.be.an 'array'
          chai.expect(res).to.eql [ 15 ]
          done()

    describe 'attribute lookup in continue tree', ->
      it 'should return null', (done) ->
        direct = (orig, data) ->
          subtree = orig.continue 'directcalc'
          subtree.deliver data
          t = subtree.then 'tripled', (c, d) ->
            c.set 'existant2', 'foo'
            chai.expect(c.get('non-existant1')).to.equal null
            d * 3

        t = Root()
        t.deliver 5
        .all [direct]
        .finally (c, res) ->
          chai.expect(c.get('existant2')).to.equal 'foo'
          chai.expect(res).to.be.an 'array'
          chai.expect(res).to.eql [ 15 ]
          done()

    describe 'attribute lookup in parent continue tree', ->
      it 'should return null', (done) ->
        direct = (orig, data) ->
          subtree = orig.continue 'directcalc'
          subtree.deliver data
          t = subtree.then 'tripled', (c, d) ->
            chai.expect(c.get('non-existant1')).to.equal null
            chai.expect(c.get('existant2')).to.equal 'foo'
            d * 3

        t = Root()
        t.deliver 5
        .then "bar", (n, v) ->
          n.set 'existant2', 'foo'
          v
        .all "foo", [direct]
        .finally (c, res) ->
          chai.expect(c.get('existant2')).to.equal 'foo'
          chai.expect(res).to.be.an 'array'
          chai.expect(res).to.eql [ 15 ]
          done()



         #b         88  88
        #88b        88  88
       #8'`8b       88  88
      #8'  `8b      88  88
     #8YaaaaY8b     88  88
    #8""""""""8b    88  88
   #8'        `8b   88  88
  #8'          `8b  88  88

  describe 'all', ->

    describe 'with simple all', ->
      it 'should resolve', (done) ->
        y1 = (c, data) ->
          c.tree()
          .deliver data
          .then 'yep-1', ->
            1
        t = Root()
        .deliver {}
        .all [y1]
        .else (choice, e) -> # THIS ELSE CAUSES TIMEOUT!
          "ignore me"
        .finally (choice, res) ->
          chai.expect(res).to.eql [1]
          done()

    describe 'all() with no tasks', ->
      it 'should give error', (done) ->
        Root()
        .deliver true
        .then 'foo', ->
          return false
        .all 'empty-all', []
        .finally (c, val) ->
          chai.expect(val).to.be.instanceof Error
          chai.expect(val.message).to.include 'No tasks'
          done()

    describe "eating items in subtrees within all", ->
      it 'should resolve', (done) ->
        a = (choice, data) ->
          choice.tree()
          .deliver data
          .then (choice, data) ->
            item = choice.getItem -> true
            choice.eatItem item
            data

        b = (choice, data) ->
          choice.tree()
          .deliver data
          .then (choice, data) ->
            item = choice.getItem -> true
            choice.eatItem item
            data

        initialData =
          items: [
            { id: 1 }
            { id: 2 }
          ]

        t = Root()
        .deliver initialData
        .all [a, b]
        .finally (choice, data) ->
          chai.expect(choice.availableItems()).to.be.empty
          done()

    describe "eating items in branches within all", ->

      test = (brancher, done) ->
        initialData =
          items: [
            { id: 1 }
            { id: 2 }
          ]
        t = Root()
        .deliver initialData
        .all [brancher]
        .finally (choice, data) ->
          chai.expect(choice.availableItems()).to.not.be.empty
          done()

      it 'should resolve', (done) ->
        brancher = (choice, data) ->
          choice.tree()
          .deliver data
          .then (choice, data) ->
            choice.branch 'a', (choice, data) ->
              item = choice.getItem -> true
              choice.eatItem item
              data
            choice.branch 'b', (choice, data) ->
              item = choice.getItem -> true
              choice.eatItem item
              data
        test brancher, done

      it 'with continue wraps should resolve', (done) ->
        brancher = (choice, data) ->
          choice.tree()
          .deliver data
          .then (c, data) ->
            c.continue()
            .deliver(data)
            .then (c, data) ->
              c.continue()
              .deliver(data)
              .then (choice, data) ->
                choice.branch 'a', (choice, data) ->
                  item = choice.getItem -> true
                  choice.eatItem item
                  data
                choice.branch 'b', (choice, data) ->
                  item = choice.getItem -> true
                  choice.eatItem item
                  data
        test brancher, done


    describe 'with all & return values', ->

      y1 = (c, data) ->
        c.tree()
        .deliver data
        .then 'yep-1', ->
          1
      y2 = (c, data) ->
        c.tree()
        .deliver data
        .then 'yep-2', ->
          2
      y3 = (c, data) ->
        c.tree()
        .deliver data
        .then 'yep-3', ->
          3

      shouldResolve = (n1,n2,n3) ->
        it 'should resolve', (done) ->
          t = Root()
          t.deliver {}
          .all [y1, y2, y3]
          .then 'all-yep', (choice, data) ->
            chai.expect(data).to.eql [1,2,3]
            data
          .all [n1, n2, n3]
          .then 'all-nope', (choice, data) ->
            {}
          .else 'all-nope-else', (choice, result) ->
            if result.data?
              data = result.data
            else
              data = result
            chai.expect(data).to.eql
              yeps: [1,2,3]
              nopes: 1
            return data
          .finally (choice, data) ->
            chai.expect(choice.namedPath()).to.eql ['all-yep', 'all-nope-else']
            chai.expect(data).to.eql
              yeps: [1,2,3]
              nopes: 1
            done()
            true

      describe 'with throws', ->
        n1 = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope-1', (path, data) ->
            e = new Error 'nope-1'
            e.data =
              yeps: data
              nopes: 1
            throw e
        n2 = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope-2', (path, data) ->
            e = new Error 'nope-2'
            e.data =
              yeps: data
              nopes: 2
            e
        n3 = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope-3', (path, data) ->
            e = new Error 'nope-3'
            e.data =
              yeps: data
              nopes: 3
            throw e
        shouldResolve n1, n2, n3

      describe 'with aborts', ->
        n1 = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope-1', (n, data) ->
            n.abort 'nope-1', {
              yeps: data
              nopes: 1
            }
        n2 = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope-2', (n, data) ->
            n.abort 'nope-2', {
              yeps: data
              nopes: 2
            }
        n3 = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope-3', (n, data) ->
            n.abort 'nope-3', {
              yeps: data
              nopes: 3
            }
        shouldResolve n1, n2, n3

    describe 'with all & branches', ->
      it 'should resolve with result per branch', (done) ->
        brancher = (orig, data) ->
          orig.tree 'calc'
          .deliver data
          .then (choice) ->
            choice.branch 'doubled', (c, d) ->
              d * 2
            choice.branch 'squared', (c, d) ->
              d * d
        direct = (orig, data) ->
          orig.tree 'directcalc'
          .deliver data
          .then 'tripled', (c, d) ->
            d * 3

        expected = [
          [10, 15]
          [25, 15]
        ]

        Root()
        .deliver 5
        .all [brancher, direct]
        .finally (c, res) ->
          chai.expect(res).to.be.an 'array'
          exp = expected.shift()
          chai.expect(res).to.eql exp
          done() if expected.length is 0


  #8888888ba
  #8      "8b
  #8      ,8P
  #8aaaaaa8P'  ,adPPYYba,   ,adPPYba,   ,adPPYba,
  #8""""88'    ""     `Y8  a8"     ""  a8P_____88
  #8    `8b    ,adPPPPP88  8b          8PP"""""""
  #8     `8b   88,    ,88  "8a,   ,aa  "8b,   ,aa
  #8      `8b  `"8bbdP"Y8   `"Ybbd8"'   `"Ybbd8"'

  describe 'race', ->

    describe 'with race & return values', ->
      it 'should resolve', (done) ->
        multiply = (multiplier, orig, data) ->
          orig.tree 'a'
          .deliver data
          .then (c, d) ->
            d * multiplier
        Root()
        .deliver 5
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
          orig.tree 'a'
          .deliver data
          .then (c, d) ->
            d * multiplier
            c.abort "I would've returned #{d*multiplier}, but chose not to"
        Root()
        .deliver 5
        .race [
          multiply.bind @, 2
          multiply.bind @, 3
        ]
        .finally (c, res) ->
          chai.expect(res).to.be.instanceof Error
          chai.expect(res.message).to.equal "I would've returned 15, but chose not to"
          done()
      it 'should resolve with value if given', (done) ->
        multiply = (multiplier, orig, data) ->
          orig.tree 'a'
          .deliver data
          .then (c, d) ->
            d * multiplier
            c.abort "I would've returned #{d*multiplier}, but chose not to", multiplier
        Root()
        .deliver 5
        .race [
          multiply.bind @, 2
          multiply.bind @, 3
        ]
        .finally (c, res) ->
          chai.expect(res).to.equal 3
          done()


  #8b           d88                           88
  #88b         d888                           88
  #8`8b       d8'88                           88
  #8 `8b     d8' 88  ,adPPYYba,  8b       d8  88,dPPYba,    ,adPPYba,
  #8  `8b   d8'  88  ""     `Y8  `8b     d8'  88P'    "8a  a8P_____88
  #8   `8b d8'   88  ,adPPPPP88   `8b   d8'   88       d8  8PP"""""""
  #8    `888'    88  88,    ,88    `8b,d8'    88b,   ,a8"  "8b,   ,aa
  #8     `8'     88  `"8bbdP"Y8      Y88'     8Y"Ybbd8"'    `"Ybbd8"'
                                     #8'
                                    #8'
  describe 'maybe', ->

    describe 'with simple positive', ->
      it 'should resolve', (done) ->
        y1 = (c, data) ->
          c.tree()
          .deliver data
          .then 'yep-1', ->
            1
        Root()
        .deliver {}
        .maybe [y1]
        .else (choice, e) ->
          throw new Error "ignored"
        .finally (choice, res) ->
          chai.expect(res).to.eql [1]
          done()

    describe 'with simple negative via throw', ->
      it 'should resolve', (done) ->
        n = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope', ->
            throw "nope"
        Root()
        .deliver 'hello'
        .maybe [n]
        .else (choice, data) ->
          data
        .finally (choice, res) ->
          chai.expect(res).to.equal "hello"
          done()

    describe 'with simple negative via abort', ->
      it 'should resolve', (done) ->
        n = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope', (n) ->
            n.abort "nope"
        Root()
        .deliver 'hello'
        .maybe [n]
        .finally (choice, res) ->
          chai.expect(res).to.equal "hello"
          done()

    describe 'with maybe & return values', ->
      it 'should resolve', (done) ->
        multiply = (multiplier, orig, data) ->
          orig.tree 'a'
          .deliver data
          .then (c, d) ->
            d * multiplier
        Root()
        .deliver 5
        .maybe [
          multiply.bind @, 2
          multiply.bind @, 3
        ]
        .finally (c, res) ->
          chai.expect(res).to.eql [10, 15]
          done()

    describe 'with maybe & branched return values', ->
      it 'should resolve', (done) ->
        expected = [
          [10, 15]
          [10, 45]
          [20, 15]
          [20, 45]
        ]
        multiply = (multiplier, orig, data) ->
          orig.tree "a#{multiplier}"
          .deliver data
          .then (c, d) ->
            c.branch 'regular', ->
              d * multiplier
            c.branch 'super', ->
              d * multiplier * multiplier
        Root()
        .deliver 5
        .maybe [
          multiply.bind @, 2
          multiply.bind @, 3
        ]
        .finally (c, res) ->
          chai.expect(res).to.eql expected.shift()
          done() if expected.length is 0

    describe 'with maybe & throw', ->
      it 'should resolve', (done) ->
        multiply = (multiplier, orig, data) ->
          orig.tree 'a'
          .deliver data
          .then (c, d) ->
            d * multiplier
            throw new Error "I would've returned #{d*multiplier}, but chose not to"
        Root()
        .deliver 5
        .maybe [
          multiply.bind @, 2
          multiply.bind @, 3
        ]
        .else (c, res) ->
          chai.expect(res).to.be.a 'number'
          chai.expect(res).to.equal 5
          done()

    describe 'with maybe & abort', ->
      it 'should resolve', (done) ->
        multiply = (multiplier, orig, data) ->
          orig.tree 'a'
          .deliver data
          .then (c, d) ->
            d * multiplier
            c.abort "I would've returned #{d*multiplier}, but chose not to"
        Root()
        .deliver 5
        .maybe [
          multiply.bind @, 2
          multiply.bind @, 3
        ]
        .else (c, res) ->
          chai.expect(res).to.be.a 'number'
          chai.expect(res).to.equal 5
          done()


   #d88888ba
  #8"     "8b
  #8,
  #Y8aaaaa,     ,adPPYba,   88,dPYba,,adPYba,    ,adPPYba,
    #"""""8b,  a8"     "8a  88P'   "88"    "8a  a8P_____88
          #8b  8b       d8  88      88      88  8PP"""""""
  #8a     a8P  "8a,   ,a8"  88      88      88  "8b,   ,aa
   #Y88888P"    `"YbbdP"'   88      88      88   `"Ybbd8"'

  describe 'some', ->

    describe 'with simple some', ->
      it 'should resolve', (done) ->
        y1 = (c, data) ->
          Root()
          .deliver data
          .then 'yep-1', ->
            1
        Root()
        .deliver {}
        .some([y1])
        .else (choice, e) -> # THIS ELSE CAUSES TIMEOUT!
          console.log "FAILED!", e
        .finally (choice, res) ->
          chai.expect(res).to.eql [1]
          done()

    describe 'with some, returning values & errors', ->
      it 'should resolve', (done) ->

        y1 = (c, data) ->
          c.tree()
          .deliver data
          .then 'yep-1', ->
            1
        y2 = (c, data) ->
          c.tree()
          .deliver data
          .then 'yep-2', ->
            throw new Error 'Foo'
        y3 = (c, data) ->
          c.tree()
          .deliver data
          .then 'yep-3', (path, data) ->
            3

        n1 = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope-1', (path, data) ->
            e = new Error ""
            e.data =
              yeps: data
              nopes: 1
            throw e
        n2 = (c, data) ->
          c.tree()
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
          c.tree()
          .deliver data
          .then 'nope-3', (path, data) ->
            e = new Error ""
            e.data =
              yeps: data
              nopes: 3
            throw e

        Root()
        .deliver {}
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

    describe 'with some, aborts & returning values', ->
      it 'should resolve', (done) ->

        y1 = (c, data) ->
          c.tree()
          .deliver data
          .then 'yep-1', ->
            1
        y2 = (c, data) ->
          c.tree()
          .deliver data
          .then 'yep-2', (n) ->
            n.abort 'Foo'
        y3 = (c, data) ->
          c.tree()
          .deliver data
          .then 'yep-3', (path, data) ->
            3

        n1 = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope-1', (n, data) ->
            n.abort "", {
              yeps: data
              nopes: 1
            }
        n2 = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope-2', (n, data) ->
            n.abort "", {
              yeps: data
              nopes: 2
            }
          .else 'still nope', (path, data) ->
            throw new Error "I never get thrown"
        n3 = (c, data) ->
          c.tree()
          .deliver data
          .then 'nope-3', (n, data) ->
            n.abort "", {
              yeps: data
              nopes: 3
            }

        Root()
        .deliver {}
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
        .else 'some-nope-else', (choice, data) ->
          chai.expect(data).to.be.an 'object'
          chai.expect(data.yeps).to.be.an 'array'
          chai.expect(data.yeps[0]).to.equal 1
          chai.expect(data.yeps[2]).to.equal 3
          chai.expect(data.nopes).to.equal 3
          return data
        .always (choice, data) ->
          chai.expect(choice.namedPath()).to.eql ['some-yep', 'some-nope-else']
          chai.expect(data.yeps).to.be.an 'array'
          chai.expect(data.yeps[0]).to.equal 1
          chai.expect(data.yeps[2]).to.equal 3
          chai.expect(data.nopes).to.equal 3
          done()



    #ad8888ba,
   #8"'    `"8b                             ,d                             ,d
  #8'                                       88                             88
  #8              ,adPPYba,   8b,dPPYba,  MM88MMM  ,adPPYba,  ,adPPYba,  MM88MMM
  #8             a8"     "8a  88P'   `"8a   88    a8P_____88  I8[    ""    88
  #8,            8b       d8  88       88   88    8PP"""""""   `"Y8ba,     88
   #8a.    .a8P  "8a,   ,a8"  88       88   88,   "8b,   ,aa  aa    ]8I    88,
    #"Y8888Y"'    `"YbbdP"'   88       88   "Y888  `"Ybbd8"'  `"YbbdP"'    "Y888

  describe 'contest', ->

    describe 'with simple contest', ->

      winner = (parent) ->
        parent.tree()
        .deliver()
        .then ->
          'winner'
      loser = (parent) ->
        parent.tree()
        .deliver()
        .then (n) ->
          n.abort 'loser'

      it 'aborted contestants not in results', (done) ->
        Root()
        .deliver()
        .contest [loser, loser, loser, winner]
          , (c, results) ->
            results[0]
        .then (c, res) ->
          chai.expect(res).to.eql ['winner']
          done()

      it 'fails with all aborted contestants', (done) ->
        Root()
        .deliver()
        .contest [loser, loser, loser, loser, loser]
          , (c, results) ->
            results[0]
        .else (c, res) ->
          chai.expect(res.reason).to.eql 'loser'
          done()


    describe 'with contest & simple scoring', ->
      it 'should resolve', (done) ->
        multiply = (multiplier, orig, data) ->
          orig.tree 'a'
          .deliver data
          .then "#{multiplier}", (c, d) ->
            d * multiplier
        Root()
        .deliver 5
        .contest [
          multiply.bind @, 2
          multiply.bind @, 3
        ], (c, results) ->
          paths = results.map (r) -> r.path
          idx = paths.indexOf 'root-3-then'
          results[idx]
        .finally (c, res) ->
          chai.expect(res).to.eql [15]
          done()

    describe 'with looping contest', ->
      it "should resolve in then", (done) ->
        count = 0
        contestant = (c, d) ->
          c.tree 'contestant'
          .deliver {}
          .then (c, d) ->
            count++
            "contestant-#{count}"
        Root()
        .deliver()
        .contest [contestant]
          , (c, contestants) -> # scoring
            contestants[0]
          , (n, chosen) -> # until
            return true if count is 4
            false
        .then (c, results) ->
          chai.expect(results).to.eql ["contestant-1","contestant-2","contestant-3","contestant-4"]
          done()

      it "should resolve in finally", (done) ->
        count = 0
        contestant = (c, d) ->
          c.tree 'contestant'
          .deliver {}
          .then (c, d) ->
            count++
            "contestant-#{count}"
        Root()
        .deliver()
        .contest [contestant]
          , (c, contestants) -> # scoring
            contestants[0]
          , (n, chosen) -> # until
            return true if count is 4
            false
        .finally (c, results) ->
          chai.expect(results).to.eql ["contestant-1","contestant-2","contestant-3","contestant-4"]
          done()

    describe 'contest via branching', ->
      it 'should resolve', (done) ->
        multiply = (multiplier, c, data) ->
          c.tree 'a'
          .deliver data
          .then "#{multiplier}", (c, d) ->
            c.branch 'doubled', (b, data) ->
              data * 4
            c.branch 'tripled', (b, data) ->
              data * 3
        Root()
        .deliver 5
        .contest "contest-multiply", [
          multiply.bind @, 2
        ], (c, results) ->
          paths = results.map (r) -> r.path
          idx = paths.indexOf 'root-tripled-then'
          results[idx]
        .finally 'enfin-fini',   (c, res) ->
          chai.expect(res).to.eql [15]
          done()



   #d88888ba                                   88
  #8"     "8b                                   88
  #8,                                   88
  #Y8aaaaa,    88,dPYba,,adPYba,    ,adPPYba,   88   ,d8   ,adPPYba,
    #"""""8b,  88P'   "88"    "8a  a8"     "8a  88 ,a8"   a8P_____88
          #8b  88      88      88  8b       d8  8888[     8PP"""""""
  #8a     a8P  88      88      88  "8a,   ,a8"  88`"Yba,  "8b,   ,aa 888 888 888
   #Y88888P"   88      88      88   `"YbbdP"'   88   `Y8a  `"Ybbd8"' 888 888 888

  describe "Smoke-Tests", ->

    describe 'handling a multi-dimensional template branch', ->
      it 'should produce the expected path', (done) ->
        Root()
        .deliver true
        .then 'w-image', ->
          return {}
        .else 'wo-image', ->
          return {}
        .then 'landscape', ->
          throw new chai.AssertionError 'Not landscape'
        .else 'portrait', ->
          return {}
        .else 'square', ->
          throw new chai.AssertionError 'Not square'
        .then 'large', ->
          throw new chai.AssertionError 'Too small'
        .else 'small', ->
          return {}
        .always (choice, val) ->
          # The real resolved path (always hasn't resolved yet)
          chai.expect(choice.namedPath()).to.eql ['w-image', 'portrait', 'small']
          done()

      it 'should produce the expected path also when there are sub-trees', (done) ->
        Root()
        .deliver true
        .then 'w-image', ->
          return {}
        .else 'wo-image', ->
          return {}
        .then 'landscape', ->
          throw new chai.AssertionError 'Not landscape'
        .else 'portrait', ->
          return {}
        .else 'square', ->
          throw new chai.AssertionError 'Not square'
        .then 'faces', (choice, data) ->
          choice.tree()
          .deliver data
          .then 'face-detection', ->
            {}
          .then 'match-people', ->
            {}
          .then 'find-friends', ->
            throw new chai.AssertionError 'Trying hard'
          .else 'no-friends', (path, faces) ->
            {}
        .always 'cropping', ->
          {}
        .always (choice, val) ->
          # The real resolved path (always hasn't resolved yet)
          chai.expect(choice.namedPath()).to.eql ['w-image', 'portrait', 'faces', 'cropping']
          done()
          true

      it 'should produce the expected song with sub-trees', (done) ->
        exp =
          path: ['w-image', 'portrait', 'faces']
          children: [
            path: ['face-detection', 'match-people', 'no-friends']
            children: []
          ]
        Root()
        .deliver true
        .then 'w-image', ->
          return {}
        .else 'wo-image', ->
          return {}
        .then 'landscape', ->
          throw new chai.AssertionError 'Not landscape'
        .else 'portrait', ->
          return {}
        .else 'square', ->
          throw new chai.AssertionError 'Not square'
        .then 'faces', (choice, data) ->
          choice.tree()
          .deliver data
          .then 'face-detection', ->
            {}
          .then 'match-people', ->
            {}
          .then 'find-friends', ->
            throw new chai.AssertionError 'Trying hard'
          .else 'no-friends', (path, faces) ->
            {}
        .then 'cropping', (c) ->
          {}
        .finally (choice, val) ->
          chai.expect(choice.source.source.toSong()).to.eql exp
          done()


    describe 'layout system simulation with safe failures', ->

      testSections = (failedComponent, done) ->
        component = (n,d) ->
          n.tree 'component'
          .deliver()
          .then failedComponent
          .else 'subcomponent-optional', ->
            true
          .then ->
            true

        post = (n,d) ->
          n.tree 'post'
          .deliver()
          .then (n) ->
            item = n.getItem (item) ->
              item
            n.eatItem item
            item
          .then component
          .else (n) ->
            n.abort('component required')
          .then failedComponent
          .else 'component-optional', ->
            true
          .all [component, failedComponent]
          .else 'components-optional', ->
            true
          .some [component, failedComponent]

        section = (n,d) ->
          n.tree 'section'
          .deliver()
          .then post
          .then ->
            'section'

        layout = (n, sections) ->
          n.tree 'layout'
          .deliver()
          .contest sections
            , (n, results) -> # scoring
              return results[0]
            , (n, chosen) -> # until
              return false if n.availableItems().length
              true

        Root()
        .deliver
          items: [
              id: 1
            ,
              id: 2
            ,
              id: 3
          ]
        .then ->
          [section]
        .then layout
        .finally (n, results) ->
          chai.expect(results.length).to.equal 3
          done()

      it 'should work w/ thrown failedComponent', (done) ->
        failedComponent = (n,d) ->
          n.tree 'failedComponent'
          .deliver()
          .then (n) ->
            throw 'failedComponent thrown'
        testSections failedComponent, done

      it 'should work w/ aborted failedComponent', (done) ->
        failedComponent = (n,d) ->
          n.tree 'failedComponent'
          .deliver()
          .then (n) ->
            n.abort('failedComponent aborted')
        testSections failedComponent, done


    describe 'alt layout system simulation', ->

      test = (done) ->

        failedComponent = (n,d) ->
          n.tree 'failedComponent'
          .deliver()
          .then (n) ->
            n.abort('failedComponent aborted')

        text = (n,item) ->
          n.tree 'text-component'
          .deliver(item)
          .then (n,item) ->
            block = n.getBlock item, (b) ->
              b.type is 'text'
            n.expect( block ).to.be.an 'object'
            n.eatBlock block
            block
          .else (n,d) ->
            n.abort "text not there", d

        video = (n,item) ->
          n.tree 'video-component'
          .deliver(item)
          .then (n,item) ->
            block = n.getBlock item, (b) ->
              b.type is 'video'
            n.expect( block ).to.be.an 'object'
            n.eatBlock block
            block
          .else (n,d) ->
            n.abort "video not there", d

        image = (n,item) ->
          n.tree 'image-component'
          .deliver(item)
          .then (n,item) ->
            block = n.getBlock item, (b) ->
              b.type is 'image'
            n.expect( block ).to.be.an 'object'
            n.eatBlock block
            block
          .else (n,d) ->
            n.abort "image not there", d

        post = (components) ->
          return (n,d) ->
            n.tree 'post'
            .deliver()
            .then (n) ->
              item = n.getItem (item) ->
                item?
              n.eatItem item
              item
            .all components
            .else (n,d) ->
              n.abort('post: missing required component',d)

        section = (name,posts) ->
          return (n,d) ->
            n.tree 'section'
            .deliver()
            .then name, ->
              true
            .all posts
            .then (n,results) ->
              name
            .else (n,d) ->
              n.abort('section: posts failed',d)

        imageSection = section('imageSection',[
            post([image])
          ])

        textSection = section('textSection',[
            post([text])
          ])

        videoTextSection = section('videoTextSection',[
            post([video,text])
          ])

        sections = [videoTextSection, imageSection, textSection]

        layout = (n) ->
          n.tree 'layout'
          .deliver()
          .contest sections
            , (n, results) -> # scoring
              return results[0]
            , (n, chosen) -> # until
              return false if n.availableItems().length
              true

        Root()
        .deliver
          items: [
              id: 1
              content: [
                {type:'text'}
                {type:'video'}
              ]
            ,
              id: 2
              content: [
                {type:'text'}
              ]
            ,
              id: 3
              content: [
                {type:'image'}
              ]
          ]
        .then layout
        .finally (n, results) ->
          chai.expect(results.length).to.equal 3
          chai.expect(results).to.eql ['videoTextSection','textSection','imageSection']
          done()

      it 'should work', (done) ->
        test done

