# Flowerflip

![Flowerflip](http://i.imgur.com/P4HF6S8.gif)

Decision-tree based Finite Domain Constraint Solver, used for building layouts for [The Grid](http://thegrid.io/).

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
