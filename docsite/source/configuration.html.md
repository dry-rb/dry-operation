---
title: Configuration
layout: gem-single
name: dry-operation
---

By default, dry-operation automatically wraps the `#call` method of your operations with failure tracking and [error handling](docs::error-handling). This is what allows you to use `#step` directly in your `#call` method.

```ruby
class CreateUser < Dry::Operation
  def call(input)
    # Step handling works in #call by default
    user = step create_user(input)
    step notify(user)
    user
  end
end
```

### Customizing wrapped methods

You can customize which methods can handled steps using the `.operate_on` class method:

```ruby
class MyOperation < Dry::Operation
  # Handle steps in both #call and #process methods
  operate_on :call, :process

  def call(input)
    step validate(input)
  end

  def process(input)
    step transform(input)
  end
end
```

### Disabling automatic wrapping

If you want complete control over method wrapping, you can disable the automatic wrapping entirely using `.skip_prepending`. In that case, you'll need to wrap your methods manually with `steps do ... end` and manage error handling yourself.

```ruby
class CreateUser < Dry::Operation
  skip_prepending

  def call(input)
    # Now you must explicitly wrap steps
    steps do
      user = step create_user(input)
      step notify(user)
      user
    end
  end
end
```

### Inheritance behaviour

Both `.operate_on` and `.skip_prepending` configurations are inherited by subclasses. This means:

- If a parent class configures certain methods to be wrapped, subclasses will inherit that configuration
- If a parent class skips prepending, subclasses will also skip prepending
- Subclasses can override their parent's configuration by calling `.operate_on` or `.skip_prepending` again
