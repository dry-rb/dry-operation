---
title: Introduction
layout: gem-single
type: gem
name: dry-operation
sections:
  - error-handling
  - configuration
  - extensions
  - design-pattern
---

dry-operation provides an expressive and flexible way for you to model your app's business operations. It provides a lightweight DSL around [dry-monads](/gems/dry-monads/), which allows you to chain together steps and operations with a focus on the happy path, while elegantly handling failures.

### Introduction

In complex business logic, it's common to have a series of operations that depend on each other. Traditionally, this leads to deeply nested conditional statements or a series of guard clauses. dry-operation provides a more elegant solution by allowing you to define a linear flow of operations, automatically short-circuiting on failure.

### Basic Usage

To use dry-operation, create a class that inherits from `Dry::Operation` and define your flow in the `#call` method:

```ruby
class CreateUser < Dry::Operation
  def call(input)
    attrs = step validate(input)
    user = step persist(attrs)
    step notify(user)
    user
  end

  private

  def validate(input)
    # Return Success(attrs) or Failure(error)
  end

  def persist(attrs)
    # Return Success(user) or Failure(error)
  end

  def notify(user)
    # Return Success(true) or Failure(error)
  end
end
```

In this example, each step (`validate`, `persist`, `notify`) is expected to return either a `Success` or `Failure` from [dry-monads](/gems/dry-monads/).

### The step method

The step method is the core of `Dry::Operation`. It does two main things:

- If the result is a `Success`, it unwraps the value and returns it.
- If the result is a `Failure`, it halts the execution throwing the failure up the call stack.

This behavior allows you to write your happy path in a linear fashion, without worrying about handling failures at each step.

### The call method

The `#call` method will catch any potential failure from the steps and return it. If it completes without encountering any failure, its return value is automatically wrapped in a `Success`. This means you don't need to explicitly return a `Success` at the end of your `#call` method.

For example, given this operation:

```ruby
class CreateUser < Dry::Operation
  def call(input)
    attrs = step validate(input)
    user = step persist(attrs)
    step notify(user)
    user  # This is automatically wrapped in Success
  end

  # ... other methods ...
end
```

When all steps succeed, calling this operation will return `Success(user)`, not just `user`.

### Handling Results

After calling an operation, you get back either a `Success` or a `Failure`. You can pattern match on this result to handle each situation:

```ruby
case CreateUser.new.(input)
in Success[user]
  puts "User #{user.name} created successfully"
in Failure[:invalid_input, errors]
  puts "Invalid input: #{errors}"
in Failure[:database_error]
  puts "Database error occurred"
in Failure[:notification_error]
  puts "User created but notification failed"
end
```

This pattern matching allows you to handle different types of failures in a clear and explicit manner.
