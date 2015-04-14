# Flowerflip
![Flowerflip](http://i.imgur.com/P4HF6S8.gif)

Decision-tree based Finite Domain Constraint Solver, used for building layouts for [The Grid](http://thegrid.io/).

## FlowerFlip overview
FlowerFlip is an API that allows the creation of promise-based decision trees. FlowerFlip allows the creation of complexe decision trees by giving the possibility to compose the decision tree of subtrees and managing how the result of these subtrees are handled in the parent decision tree.

The decision tree in FlowerFlip are composed of promises that are chain together to form the decision tree. Decision taken in the decision tree are represented using a `Choice` object.

The initial use of FlowerFlip is for Design Systems. Design system are used in TheGrid as solver for web page design as well as HTML and styling rendering of the resulting web page.

### API
The primary API for building decision trees is promise-based.
``` coffeescript
f = require 'flowerflip'
t = f.Root()
.then 'foo', (choice, val) ->
  # Do something
.else 'bar', (choice, e) ->
  # Handle error
```
### Debugging
To see more information on a running Flowerflip setup, there are two log settings available:
* `errors`: see details about failed preconditions, aborted trees, and other errors
* `asserts`: see details about failed preconditions
* `values`: see the return values of the promises in the tree
* `tree`: see details about tree execution, including which node is currently being executed
* `collection`: see details about collection fulfillment
* `branch`: see branching
* `abort`: see aborts

To use these, run Flowerflip with the `DEBUG` environment variable set, for example:
```
$ DEBUG=errors grunt test
```
You can combine them comma-separated, like `DEBUG=errors,tree`.


### Work in progress
This doc is far from being complete and may lack accuracy in certain sections as some discussions are taking place in the issues and questions still need to be answered. But this should still give you a good starting point.

## Promises
Promises are used to build decision trees. FlowerFlip provides its own implementation of promise with the `Thenable` module.

### What are promises?
Here's a very good introduction to promises: http://www.html5rocks.com/en/tutorials/es6/promises/

### Positive & Negative Promise results
When a promise returns a positive result (truthy value) the next promise to be executed in the chain will be one of the following: `then`, `all`, `some`, `always`, `finally`, `contest`, `race`, `maybe`.

If the promise returns a negative results (throw an error, falsy values, abortion of the choice object) the next promise to be called in the chain will be of type: `else`, `finally`, or `always`.

### Thenable object
The Thenable object supports the following methods:

* `then(name, onFulfilled)`
* `all(name, tasks)`
* `race(name, tasks)`
* `some(name, tasks)`
* `maybe(name, tasks)`
* `contest(name, tasks, score, resolve)`
* `always(name, onAlways)`
* `else(name, onRejected)`
* `finally(name, onFinally)`


The `then`, `all` and `race` methods behave in accordance with the [promise specification](http://www.html5rocks.com/en/tutorials/es6/promises/#toc-api) so they are not covered here.


#### some(name, tasks)
The `some` promise will be fulfilled if at least one of the promises passed in the `tasks` input parameter is fulfilled.

``` coffeescript
t.some('some', [p1, p2, p3]).then (choice, data) ->
  data
```
If one or more of `p1`, `p2`, or `p3` promises are fulfilled, the `.then` method will be called and will receive an array, for the `data` parameter, where items represent the data being returned from the promises that were fulfilled.

For example if `p1` and `p3` were fulfilled but `p2` was rejected, the `then` method would be called with an array of two items where `data[0]` and `data[1]` are the data returned by the `p1` and `p3` respectively.

If none of the tasks were fulfilled, the next `.else`, `.finally`, or `.always` following the `.some` method will be called with the last task error as the data parameter.

#### maybe(name, tasks)
The `maybe` promise is very similar to `some`. The only difference is that if all promises are rejected, the `.else`, `.finally`, or `.always` method will be called with the value that was delivered to the maybe promise instead of the last promise error.

Maybe some of these tasks will be fulfilled, if not, continue with the original data.  

#### contest(name, tasks, score, resolve)
The `contest` promise will execute each promise and select one of the tasks that is fulfilled as the winner of the contest.

If a `score` callback is passed in, this function will be called with the array of the fulfilled promises and an array of the return values from the fulfilled promise. If no score is passed, the first promise that was fulfilled will win the contest.

The data of the winning promise (task) is then passed to the next positive promise in the chain following the contest. If all promises are rejected the error of the last promise will be passed to the next negative promise in the chain. The winning subtree or branch will be added to the `choosenSolutions`.

##### resolve the contest
The `resolve` callback is used to determine whether the contest was "enough". If not, the contest node is cloned to under the current contest and run again. This allows looping contests until all items have been eaten, for instance. The first time the contest is executed, `choosenSolutions` will be empty.

If `resolve` returns false, a new contest node is added to the decision tree. This new contest will be resolved using the same tasks and the `score` callback will be called with the current contest `results`. Each time a contest and its inner contests choose a solution, the solution is added to the chosenSolutions array. This object is passed in the `score` callback for inner contest so we can score based on current but also previous results.  

Let's take this example:

``` javascript
.contest sections
    , (n, results, chosenSolutions) -> # scoring
      #return results[0]
      before = chosenSolutions.map (c) -> c.choice.toSong()
      for r in results
        song = before.concat [r.choice.toSong()]
        r.score = score.grade song
        r.total = r.score.map((s) -> s.score).reduce (a, b) -> a+b
      results.sort compare
      results[0]
    , (n, chosen) -> # until
      return false if n.availableItems().length
      true

```
In this example, `sections` are the subtrees representing the decision tree of each selected sections by the user spectrum.

The choice path of the chosen solutions is concatenated with the results of each tasks in the inner contests. If its the parent contest, `chosenSolutions` is empty. Fletcher is then called with the `score` object. `score.grade` will give a score for each rules in the Fletcher harmony. The score array is then map reduce in order to calculate the total score for the concatenated choice path.

The winning path according to the Fletcher harmony will then be added to the chosenSolutions and this will go on until there's no more availableItems to be eaten by sections.

Let's say we have section A, B and C. The first contest will try each section A, B and C. If branching is used, they will each eat items independently. At the end of the first contest, Fletcher will evaluate the winning section. Then, if some available items are remaining in each branch, a second contest will be created. Section A, B and C will then be contested again, and they will each eat new items.

#### always(name, onAlways)
The name of this one is self-explanatory, regardless of whether the previous promise in the chain generates a positive or negative result this promise will be called. Note that the data it receives will vary.

#### else(name, onElse)
The `else` promise will only be called if the previous promise in the chain generated an error or aborted its choice.

#### finally(name, onFinally)
`finally` is like `always` except it will mark the current promise as final. Promises added after `finally` will never be called and doing so will actually throw an exception.

### Composites
The `all`, `maybe`, `race`, and `contest` promises are called composite promise since they are composed of sub-promises and will evaluate as one single result in the decision tree execution.

### Thenable input & output
Non-composite thenables will receive `Choice` and `Data` parameters. `Choice` is covered in a later section. `Thenable` will pass the return value of a promise to the next one in the chain.

``` coffeescript
p.then 'thenName', (choice, data) ->
    data * 2
 .finally 'end', (choice, data) ->
   console.log data
```
If `then` is delivered a value of `10`, `console.log` in `finally` will output `20`.

## Decision tree
A decision tree is a chain of promises. FlowerFlip allows the creation of complex decision trees by providing support for subtrees and branches.

Defining a chain of promises such as the following doesn't actually execute it.

``` coffeescript
root.then (choice, data) ->
        data
    .else (choice, data) ->
        data
    .then (choice, data) ->
        data
```
FlowerFlip provides the `BehaviorTree` module to manage the complexity of decision trees and support their execution. More on `BehaviorTree` in the next section.

### Root promise of the tree
FlowerFlip provide the `Root` module to initialize the root promise of the decision tree. The root module does the following:

* defines on the `options` object which `Choice` instance will be used in the decision tree
* creates an instance of `BehaviorTree` and passes in the `options` object
* creates an instance of `Root` as the promise root

### Execution of the decision tree
In order to execute a decision tree or subtree, some data must be delivered to it using the `Thenable.deliver` method.

```coffeescript
t = Root()
t.deliver someData
```
`someData` will be passed to the first promise in the tree. This promise will return a value that will then be passed to the next one and so on. The `data` parameter of promises is the only mutable object in decision trees.


## Behavior trees
The `BehaviorTree` module supports the execution of the promise decision tree.

When calling `deliver` on the root promise, the behavior tree attached to the promise will be executed calling `BehaviorTree.execute(...)`. A behavior tree is composed of nodes. When creating a `BehaviorTree` instance a root node is created.

More than one promise can lead to a node in the tree and a node can have multiple destinations. Consider this example:

``` coffeescript
root.then 'then0', (choice, data) ->
      data
    .then 'then1', (choice, data) ->
      data
    .else 'else0', (choice, data) ->
      data
    .then 'then2', (choice, data) ->
      data
    .else 'else1', (choice, data) ->
      data

```

`else0` as two sources (`then0` and `then1`) and two destinations (`then2` and `else1`). `BehaviorTree` will walk the promise chain to create all required sources and destinations.

When chaining a promise, a new node will be registered to the tree. The registration will get the node representing the source promise in the tree and add the current node to the `Destinations` array of the source node. The source node will also be added to the `Sources` collection of the current node. Doing this creates an edge between these two nodes in the tree.

If the sources promise has branches, the branches will be added as source of the current node and the current node will be added as destination. This is the reason why, if using branches outside of `contest` multiple executions can occur of the promise following the branches.

What leads to a node is a choice made in the decision tree. The `Choice` module is used to represent the transition from one promise to another in the `BehaviorTree`. More on `Choice` in the next section.

When delivering data to a tree, the data being delivered to the tree will be used to feed the `Choice.attributes` object if the data is an object other than an array.

### Solution path
As explained in more detail in the Choice section, the behavior tree will keep track of all the decision made within the decision tree. Each node has a name and when a Choice is made, the name of that node is added to the solution path.

Let's assume all `then` promises will be fulfilled in the following example:
``` coffeescript
root.then 'then0', (choice, data) ->
      data
    .then 'then1', (choice, data) ->
      data
    .else 'else0', (choice, data) ->
      data
    .then 'then2', (choice, data) ->
      data
    .else 'else1', (choice, data) ->
      data
```
The execution of this tree would give the following path: `['then0', 'then1', 'then2']`

If the first `then` promise is rejected, and the `else` is fulfilled this would give the following path:

 `['then0', 'else0', 'then2']`


### Subtrees
The `BehaviorTree` module allows the creation of `Subtrees` for scenarios where out of a single promise, several decisions must be taken before continuing in the main tree. Subtrees should be used in composite promise scenarios: `maybe`, `some`, `contest`, `all`, and `race`.

Subtrees are used to create decision components like the following:

``` coffeescript
module.exports = (choice, data) ->
  tree = choice.continue 'layout'
  tree.deliver data
  .then 'user', (c, d) ->
    d
  .else 'derived', (c, d) ->
    d
  .then (c, d) ->
    d
```
Once the execution of the subtree is done, depending on which composite promise is used, the result of the fulfilled leaf of the subtree will be passed to the next promise in the parent tree.

This module can then be added into a decision tree easily and will take part in the execution of the root tree.

Subtrees have two modes, `continue` and `tree`, and are created using `Choice.continue` and `Choice.tree` respectively. `Choice.continue` subtrees will add the solution path of the subtree to its parent solution path. `Choice.tree` subtrees will add the name of the subleaf that is fulfilled in the subtree to the parent solution path and add a child path to the solution path of the subtree.

#### No `finally` with subtrees
`.finally` should not be called on a subtree since the subtree is part of the parent decision tree. Calling `.finally` on the subtree would prevent further promise to be called.

#### Promises that returns promises
If a promise returns a promise, a subtree will be created using that promise as the root of the subtree.

### Visualizing the tree
`BehaviorTree` provides the `toDOT` method that will output graphviz data that can then be used in a tool like the following to generate an image of the tree: http://www.webgraphviz.com


## Choices
`Choice` represents the decision edges between nodes for which a decision was made to transition from the source node to the destination node.

### Path
If a promise has a name, that name will be added to the `path` when it is resolved. On the tree node, the path is used to identify the choice object that led to this node in the tree.

### Attributes
Data can be added to a choice by calling its `set` method using a key-value pair. Decisions to fulfill or reject a promise can then be made in later promises using attribute values via the `get` method. These properties can be used for any useful purpose.

`get` will look in the current choice attributes if a key exists in the `attributes` object, if not, it will look at the parent source choice and so on until a matching key is found or the root choice is reached.  

### Items
If the data passed to the root promise of the tree contains a property named `items`, the value of the items will be added to `Choice.attributes` of the root choice.

These item can be obtained using `getItem` and can be eaten using `eatItem`. Items can be, for example, posts from users of The Grid for their websites. For a concrete example, see the Design System section.

Once an item is eaten, it is no longer available for the current choice and its child choices. Items are immutable, meaning they will always remain in the `Choice.attributes.items` object but will be filtered from the `Choice.attributes.itemsEaten` object.

#### getItem
The `getItem` function can be passed a callback function. If no callback is received, the first item in the `availableItems` collection will be returned. Otherwise, the callback function will be called for each available items. If the callback function returns a `truthy` value for a given item, that item will then be returned from the `getItem` function otherwise the loop will continue until there's no more available items.

#### Blocks
Items can have blocks, which is the item content. For example, an HTML item would be composed of blocks representing the innerHTML of the item tag.

Blocks can be obtained and eaten in the same fashion as items using the `getBlock` and `eatBlock` methods.

### Abort
A choice can be aborted. This should only be done in subtrees used in composites. The remaining promises of the subtree will not be called. Depending on which composite promise was used, if you abort all the subtrees then the negative destination of the composite will be called.

### Song
The path of a `Choice` including child paths from subtrees or branches can be obtained by calling the `toSong` method. This is used by [Fletcher](https://github.com/the-grid/Fletcher).

## Branches
Branches are used to create independent execution of a portion of the tree.

When creating a branch, the choice from which the branch is created is aborted. The branch is then registered as a destination for the source node of the aborted choice. The destination nodes of the branches are then copied from the aborted node.

A branch is created using the `Choice.branch` method.

The branch uses a new root `Choice` that copies the attributes from the aborted node. By copying the attributes, the branch will have its own copy of available items meaning that, contrary to subtrees, two sibling branches can eat the same item.

The branch is then resolved, resulting in the execution of that branch's promises and if fulfilled, will then chain to one of its destinations.

In most cases, branches will be used within contest, since contest is the only composite that delivers only one result. If using branches in other composites, an independent execution of the entire decision tree will occur for each branch that is fulfilled.

### Path
If you do a branch within a `choice.continue` subtree, the complete path of the branch decision tree will be added to the path of the parent tree.

```coffeescript
path: ['parent_decision1', 'parent_decision2', 'branch_decision1', 'branch_decision2', 'parent_decision3']
```

If you do a branch within a choice.tree subtree, if the branch resolve, the name of the leaf choice of the branch will be added to the path of the parent tree and a child-path will be added to the solution to define the decision path of the branch:

```coffeescript
path:  ['parent_decision1', 'parent_decision2', 'branch_decision2', 'parent_decision3']
child:  ['branch_decision1', 'branch_decision2']
```

## Programmer errors
Since layout filters usually utilize multiple components, which in turn may utilize components of their own, it is possible for a component to receive data it didn't expect. These should be treated as programmer errors instead of failed preconditions, and handled via `choice.error`.

``` coffeescript
.then (choice, item) ->
  unless item
    choice.error('Item expected')
```

## Design Systems
Design systems are used in The Grid as solvers for web page designs as well as HTML and styling rendering of the resulting web page.

FlowerFlip is the API that allows the creation of design systems. A central part of a design system is the decision tree used to make all the design decisions needed to create a web page.

A decision tree is composed of all the possible choices that can be made and it also defines how these choices relate to each other. Choices can be grouped, contests can be made, etc.

Design systems must make decisions at two main levels: page wide decision trees and section decision trees.

Design systems are used to solve the design of a page of a web site. Web pages built with The Grid are, at least at this point, composed of sections. Simple sections are rectangles that take 100% of the page's width. Sections can contain what we call Posts, Reposts and/or Components. A Post is a group of Components. Reposts represent social media posts a user "re-posts" to their website. Components represent HTML elements.

Design systems built with FlowerFlip will therefore contain a set of decisions for page wide configuration and a set of decisions for the sections. The section decisions are decomposed as Post, Repost, and Component decision trees.

### Page wide decisions
Page wide decisions include but are not limited to:
* which Typography to use
* which color scheme to use (example: light colors, dark, muted + saturated, etc.)
* what kind of spectrum the user chose or the best one that fits the available content (example: informal voice, entertaining colors, use image filter, etc.)

### Section decisions
A section is a portion of a web page. The section is composed of one or more posts. A post is some content the user sent to The Grid (image, text, video, social media post, etc.).

A post (aka: item) is composed of blocks. A block is a piece of content within the post (example: header `h1` tag, image `img` tag, paragraph `p` tag, etc.).

Section decisions deal with how well the available posts fit into a given section. Some examples of decisions that need to be made in a section:
* does the post contain the required block for the section?
* does the image block in the post have the characteristics needed for the given section?
* does the length of the component text fit in the section?

## Integration of FlowerFlip in The Grid
Poly is using design systems as the solver for web page design. Poly is responsible for choosing the design system(s) that will be used. It's also Poly that is responsible to provide to the design system the user configuration and the available items in GOM representation.

Item = user post sent using grid-chrome or iOS app.

The design system will return the solution tree and the HTML rendered page. Poly will persist the solution tree for later analysis and comparison with later updates of the page.

## Design system input
At this stage, the promise tree is built but not executed. In order to execute the tree, some data must be delivered to the root promise. The data passed in is the user's configuration and GOM representation of the user's posts (aka. items).

Here's an example of site configuration (WIP for config section):

```
[
    config:
  spectrums:
      voice:
    type: -0.4
        personality:
    colour:
       palette: -0.4
       tone: -0.2
          intensity: .3
         application: .2
      imageFilter:
    active: 1
    application: .4
    intensity: .4

    items: [
            id: '029384-234'
          content: [
            type: 'h1'
            text: 'My H1'
            html: '<h1>My H1</h1>'
        ,
            id: 'foo'
            type:'video',
html:'<video></video>',
cover:
  src: 'cover.jpg'
  orientation: 'landscape'
  width: 1000
  height: 1000
       ]
    ]
]
```

### Item data in GOM
Before being processed by FlowerFlip, when a user sends a post to The Grid, this post is analyzed and some metadata is generated for it. Examples of generated metadata:
* text length
* image color palette
* saliency region in an image

FlowerFlip will receive a GOM representation of the post so the GOM object can be used to make precise and accurate design decisions.
