---
title: Error Handling
layout: gem-single
name: dry-operation
---

When using dry-operation, errors are handled through the `Failure` type from [dry-monads](/gems/dry-monads/). Each step in your operation should return either a `Success` or `Failure` result. When a step returns a `Failure`, the operation short-circuits, skipping the remaining steps and returning the failure immediately.

You'll usually handle the failure from the call site, where you can pattern match on the result to handle success and failure cases. However, sometimes it's useful to encapsulate some error handling logic within the operation itself.

### Global error handling

You can define a global failure handler by implementing an `#on_failure` method in your operation class. This method is only called to perform desired side effects and it won't affect the operation's return value.

```ruby
class CreateUser < Dry::Operation
  def initialize(logger:)
    @logger = logger
  end

  def call(input)
    attrs = step validate(input)
    user = step persist(attrs)
    step notify(user)
    user
  end

  private

  def on_failure(failure)
    # Log or handle the failure globally
    logger.error("Operation failed: #{failure}")
  end
end
```

The `#on_failure` method can optionally accept a second argument that indicates which method encountered the failure, allowing you more granular control over error handling:

```ruby
class CreateUser < Dry::Operation
  def initialize(logger:)
    @logger = logger
  end

  def call(input)
    attrs = step validate(input)
    user = step persist(attrs)
    step notify(user)
    user
  end

  private

  def on_failure(failure, step_name)
    case step_name
    when :validate
      logger.error("Validation failed: #{failure}")
    when :persist
      logger.error("Persistence failed: #{failure}")
    when :notify
      logger.error("Notification failed: #{failure}")
    end
  end
end
```
