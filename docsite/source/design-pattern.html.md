---
title: Design Pattern
layout: gem-single
name: dry-operation
---

dry-operation implements a pattern that closely resembles monadic composition, particularly the `Result` monad, and the Railway Oriented Programming pattern. Understanding these monadic concepts can provide deeper insight into how dry-operation works and why it's designed this way.

### Monadic composition

In functional programming, a monad is a structure that represents computations defined as sequences of steps. A key feature of monads is their ability to chain operations, with each operation depending on the result of the previous one.

dry-operation emulates this monadic behavior through its `#step` method and the overall structure of operations.

In monadic terms, the `#step` method in `Dry::Operation` acts similarly to the `bind` operation:

1. It takes a computation that may succeed or fail (returning `Success` or `Failure`).
1. If the computation succeeds, it extracts the value and passes it to the next step.
1. If the computation fails, it short-circuits the entire operation, skipping subsequent steps.

This behavior allows for clean composition of operations while handling potential failures at each step.

### Railway Oriented Programming

The design of dry-operation closely follows the concept of Railway Oriented Programming, a way of structuring code that's especially useful for dealing with a series of operations that may fail.

In this model:

- The "happy path" (all operations succeed) is one track of the railway.
- The "failure path" (any operation fails) is another track.

Each step is like a switch on the railway, potentially diverting from the success track to the failure track.

dry-operation implements this pattern by allowing the success case to continue down the method, while immediately returning any failure, effectively "switching tracks".
