chai = require 'chai' unless chai
SubtreeResults = require '../lib/SubtreeResults'
Choice = require '../lib/Choice'

describe 'Subtree Results', ->
  describe 'enumerating branches', ->
    it 'should provide single for singular values', (done) ->
      r = new SubtreeResults 2
      a = new Choice 'a'
      b = new Choice 'b'
      r.handleResult r.fulfilled, 0, a, 1
      r.handleResult r.fulfilled, 1, b, 2
      branches = r.getBranches()
      chai.expect(branches.length).to.equal 1
      chai.expect(branches[0].length).to.equal 2
      values = branches[0].map (b) -> b.value
      chai.expect(values).to.eql [1, 2]
      done()
    it 'should provide single for three singular values', (done) ->
      r = new SubtreeResults 2
      a = new Choice 'a'
      b = new Choice 'b'
      c = new Choice 'c'
      r.handleResult r.fulfilled, 0, a, 1
      r.handleResult r.fulfilled, 1, b, 2
      r.handleResult r.fulfilled, 2, c, 3
      branches = r.getBranches()
      chai.expect(branches.length).to.equal 1
      chai.expect(branches[0].length).to.equal 3
      values = branches[0].map (b) -> b.value
      chai.expect(values).to.eql [1, 2, 3]
      done()
    it 'should provide two for branched values', (done) ->
      r = new SubtreeResults 2
      a = new Choice 'a'
      b = new Choice 'b'
      c = new Choice 'c'
      r.handleResult r.fulfilled, 0, a, 1
      r.handleResult r.fulfilled, 0, b, 2
      r.handleResult r.fulfilled, 1, c, 3
      branches = r.getBranches()
      chai.expect(branches.length).to.equal 2
      chai.expect(branches[0].length).to.equal 2
      values = branches[0].map (b) -> b.value
      chai.expect(values).to.eql [1, 3]
      chai.expect(branches[1].length).to.equal 2
      values = branches[1].map (b) -> b.value
      chai.expect(values).to.eql [2, 3]
      done()
    it 'should provide four for branched values when two have branched', (done) ->
      r = new SubtreeResults 2
      a = new Choice 'a'
      b = new Choice 'b'
      c = new Choice 'c'
      d = new Choice 'd'
      r.handleResult r.fulfilled, 0, a, 1
      r.handleResult r.fulfilled, 0, b, 2
      r.handleResult r.fulfilled, 1, c, 3
      r.handleResult r.fulfilled, 1, d, 4
      branches = r.getBranches()
      chai.expect(branches.length).to.equal 4
      chai.expect(branches[0].length).to.equal 2
      values = branches[0].map (b) -> b.value
      chai.expect(values).to.eql [1, 3]
      chai.expect(branches[1].length).to.equal 2
      values = branches[1].map (b) -> b.value
      chai.expect(values).to.eql [1, 4]
      chai.expect(branches[2].length).to.equal 2
      values = branches[2].map (b) -> b.value
      chai.expect(values).to.eql [2, 3]
      chai.expect(branches[3].length).to.equal 2
      values = branches[3].map (b) -> b.value
      chai.expect(values).to.eql [2, 4]
      done()
    it 'should provide six for branched values when two have branched', (done) ->
      r = new SubtreeResults 2
      a = new Choice 'a'
      b = new Choice 'b'
      c = new Choice 'c'
      d = new Choice 'd'
      e = new Choice 'e'
      r.handleResult r.fulfilled, 0, a, 1
      r.handleResult r.fulfilled, 0, b, 2
      r.handleResult r.fulfilled, 1, c, 3
      r.handleResult r.fulfilled, 1, d, 4
      r.handleResult r.fulfilled, 1, e, 5
      branches = r.getBranches()
      chai.expect(branches.length).to.equal 6
      done()
    it 'should provide four for branched values when two have branched', (done) ->
      r = new SubtreeResults 2
      a = new Choice 'a'
      b = new Choice 'b'
      c = new Choice 'c'
      d = new Choice 'd'
      e = new Choice 'e'
      r.handleResult r.fulfilled, 0, a, 1
      r.handleResult r.fulfilled, 0, b, 2
      r.handleResult r.fulfilled, 1, c, 3
      r.handleResult r.fulfilled, 1, d, 4
      r.handleResult r.fulfilled, 2, e, 5
      branches = r.getBranches()
      chai.expect(branches.length).to.equal 4
      done()
