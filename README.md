# Flowerflip

![Flowerflip](http://i.imgur.com/P4HF6S8.gif)

Decision-tree based Finite Domain Constraint Solver, used for building layouts for [The Grid](http://thegrid.io/).

## Debugging

To see more information on a running Flowerflip setup, there are two log settings available:

* `errors`: see details about failed preconditions, aborted trees, and other errors
* `tree`: see details about tree execution, including which node is currently being executed

To use these, run Flowerflip with the `DEBUG` environment variable set, for example:

```
$ DEBUG=errors
```

You can combine them comma-separated, like `DEBUG=errors,tree`.

## API

The primary API for building decision trees is promise-based.

```coffeescript
f = require 'flowerflip'
t = f.Root()
.then 'foo', (choice, val) ->
  # Do something
.else 'bar', (choice, e) ->
  # Handle error
```

### Error handling

Error handling in Flowerflip is based on two separate classes of failures: *failed preconditions* and *programmer errors*.

#### Preconditions

Failed preconditions mean that a solving tree encountered data it can't deal with, for example when an image is not big enough, or when a shared item doesn't have an avatar for the original author.

Preconditions are checked with the `choice.expect` method that wraps the [chai.expect](http://chaijs.com/api/bdd/) mechanism.

```coffeescript
.then (choice, block) ->
  choice.expect(block.cover.width).to.be.above 500
```

If you want to pass data for the failure handling callbacks (`.else`, `.always`, `.finally`), you can do this by providing an additional second parameter:

```coffeescript
.then 'wide', (choice, block) ->
  choice.expect(block.cover.width, block).to.be.above 500
.else 'narrow', (choice, block) ->
  # The block received here is passed from the second callback to choice.expect above
```

#### Programmer errors

Since layout filters usually utilize multiple components, which in turn may utilize components of their own, it is possible for a component to receive data it didn't expect. These should be treated as programmer errors instead of failed preconditions, and handled via `choice.error`.

```coffeescript
.then (choice, item) ->
  unless item
    choice.error('Item expected')
```
