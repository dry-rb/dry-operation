---
title: Other monads
layout: gem-single
name: dry-operation
---

While you typically return `Success` and `Failure` from operation steps, you can also use other monads from [Dry Monads](/gems/dry-monads), which will be automaically converted to `Result` when they're passed to `step`.

### Try for exception handling

The `Try` monad is useful for wrapping code that may raise exceptions. When used with `#step`, any caught exception becomes a `Failure`:

```ruby
class ImportData < Dry::Operation
  include Dry::Monads[:try]

  # If File.read raises Errno::ENOENT, or JSON.parse raises JSON::ParserError, step will receive a
  # Failure and short-circuit the operation
  def call(file_path)
    content = step Try { File.read(file_path) }
    data = step Try { JSON.parse(content) }
    step save_to_database(data)
    Success(:imported)
  end
end
```

You can also specify which exceptions to catch:

```ruby
step Try[Errno::ENOENT, Errno::EACCES] { File.read(file_path) }
```

[Learn more about Try](/dry-monads/1.6/try/).

### Maybe for nil handling

The `Maybe` monad converts `nil` values to `None` and non-nil values to `Some`. These become `Failure` and `Success` respectively when converted to a `Result`.

```ruby
class LookupUser < Dry::Operation
  include Dry::Monads[:maybe]

  def call(user_id)
    # If find_user returns nil, Maybe(nil) becomes None, which converts to Failure
    user = step Maybe(find_user(user_id))
    
    # If user.profile is nil, this will also fail
    profile = step Maybe(user.profile)
    
    Success(profile)
  end

  private

  def find_user(id)
    # Returns user or nil
    User.find_by(id: id)
  end
end
```

[Learn more about Maybe](/dry-monads/1.6/maybe/).

### Validated for validation with error accumulation

The `Validated` monad is useful when you want to accumulate multiple validation errors instead of failing on the first one.

```ruby
class ValidateUserInput < Dry::Operation
  include Dry::Monads[:validated]

  def call(input)
    validated_data = step validate_all(input)
    
    Success(validated_data)
  end

  private

  def validate_all(input)
    # Combine multiple validations, accumulating errors
    Validated(input)
      .bind { |i| validate_name(i) }
      .bind { |i| validate_email(i) }
      .bind { |i| validate_age(i) }
  end

  def validate_name(input)
    # Valid(name) or Invalid(:invalid_name)
  end

  def validate_email(input)
    # Valid(email) or Invalid(:invalid_email)
  end

  def validate_age(input)
    # Valid(password) or Invalid(:invalid_password)
  end
end
```

When `Validated` fails, all accumulated errors are included in the `Failure`.

[Learn more about Validated](/dry-monads/1.6/validated/).

### Including monads in your operations

To use one or more monads (other than `Result`) in your operations, specify them when including `Dry::Monads`.

```ruby
class MyOperation < Dry::Operation
  include Dry::Monads[:try, :maybe, :validated]

  def call(input)
    # Now you can use Try, Maybe, and Validated
  end
end
```

The `Result` monad is always available through the `Success` and `Failure` constructors that dry-operation provides, so you don't need to explicitly include it.

### Result conversion via `#to_result`

The `step` method calls `#to_result` on any object given to it, expecting a `Dry::Monads::Success` or `Dry::Monads::Failure` in return. Implement this protocol on your own objects to make them compatible with steps.
