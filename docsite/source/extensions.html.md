---
title: Extensions
layout: gem-single
name: dry-operation
---

### Monads

The `Monads` extension provides convenient access to additional monads from dry-monads that work seamlessly with `#step`. The extension automatically converts these monads to `Result` objects, allowing you to use them directly without calling `.to_result`.

The following monads are included:
- `Try` - for exception handling
- `Maybe` - for handling nil/None/Some cases
- `Validated` - for validation with error accumulation

Note: The `Do` notation is intentionally not included, as dry-operation's `#step` serves the same purpose.

Require and include the extension in your operation class:

```ruby
require "dry/operation/extensions/monads"

class MyOperation < Dry::Operation
  include Dry::Operation::Extensions::Monads

  def call(input)
    # Use Try for exception handling
    data = step Try { fetch_data(input) }

    # Use Maybe for nil handling
    value = step Maybe(input[:optional_field])

    # Use Success/Failure as usual
    result = step process(data, value)
    
    result
  end

  def fetch_data(input)
    # May raise an exception
    HTTP.get("/data/#{input}")
  end

  def process(data, value)
    Success({data: data, value: value})
  end
end
```

#### Automatic monad conversion

Even without the extension, `#step` automatically converts any monad that responds to `#to_result`:

```ruby
class MyOperation < Dry::Operation
  include Dry::Monads[:try]

  def call(input)
    # Try is automatically converted to Result
    step Try { risky_operation(input) }
  end
end
```

This means you can use monads from dry-monads throughout your codebase without needing to call `.to_result` explicitly.

#### Migration from dry-transaction

If you're migrating from dry-transaction, you can leverage dry-monads directly:

**dry-transaction (class-level):**
```ruby
class CreateUser
  include Dry::Transaction(container: Container)

  map :process
  try :validate, catch: ValidationError
  map :create
  tee :notify
end
```

**dry-operation (instance-level):**
```ruby
class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Monads

  def call(input)
    # Wrap raw values in Success
    attrs = step Success(process(input))
    
    # Use Try for exception handling
    validated = step Try { validate(attrs) }
    
    # Wrap raw values in Success
    user = step Success(create(validated))
    
    # Just call methods directly for side effects
    notify(user)
    
    user
  end

  def process(input)
    input.merge(processed: true)
  end

  def validate(attrs)
    raise ValidationError unless attrs[:valid]
    attrs
  end

  def create(attrs)
    User.new(attrs)
  end

  def notify(user)
    Mailer.send_welcome(user)
  end
end
```

### ROM

The `ROM` extension adds transaction support to your operations when working with the [ROM](https://rom-rb.org) database persistence toolkit. When a step returns a `Failure`, the transaction will automatically roll back, ensuring data consistency.

First, make sure you have rom-sql installed:

```ruby
gem "rom-sql"
```

Require and include the extension in your operation class and provide access to the ROM container through a `#rom` method:

```ruby
require "dry/operation/extensions/rom"

class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::ROM

  attr_reader :rom

  def initialize(rom:)
    @rom = rom
    super()
  end

  def call(input)
    transaction do
      user = step create_user(input)
      step assign_role(user)
      user
    end
  end

  # ...
end
```

By default, the `:default` gateway will be used and no additional options will be passed to the ROM transaction. You can specify a different gateway and/or default transaction options when including the extension:

```ruby
include Dry::Operation::Extensions::ROM[
  gateway: :my_gateway,
  isolation: :serializable
]
```

You can also override the gateway and/or transaction options at runtime:

```ruby
transaction(gateway: :my_gateway, isolation: :serializable) do
  # ...
end
```

### Sequel

The `Sequel` extension provides transaction support for operations when using the [Sequel](http://sequel.jeremyevans.net) database toolkit. It will automatically roll back the transaction if any step returns a `Failure`.

Make sure you have sequel installed:

```ruby
gem "sequel"
```

Require and include the extension in your operation class and provide access to the Sequel database object through a `#db` method:

```ruby
require "dry/operation/extensions/sequel"

class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Sequel

  attr_reader :db

  def initialize(db:)
    @db = db
    super()
  end

  def call(input)
    transaction do
      user_id = step create_user(input)
      step create_profile(user_id)
      user_id
    end
  end

  # ...
end
```

You can pass options to the transaction either when including the extension:

```ruby
include Dry::Operation::Extensions::Sequel[isolation: :serializable]
```

Or at runtime:

```ruby
transaction(isolation: :serializable) do
  # ...
end
```

⚠️  Warning: The `:savepoint` option for nested transactions is not yet supported.

### ActiveRecord

The `ActiveRecord` extension adds transaction support for operations using the [ActiveRecord](https://api.rubyonrails.org/classes/ActiveRecord) ORM. Like the other database extensions, it will roll back the transaction if any step returns a `Failure`.

Make sure you have activerecord installed:

```ruby
gem "activerecord"
```

Require and include the extension in your operation class:

```ruby
require "dry/operation/extensions/active_record"

class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::ActiveRecord

  def call(input)
    transaction do
      user = step create_user(input)
      step create_profile(user)
      user
    end
  end

  # ...
end
```

By default, `ActiveRecord::Base` is used to initiate transactions. You can specify a different class either when including the extension:

```ruby
include Dry::Operation::Extensions::ActiveRecord[User]
```

Or at runtime:

```ruby
transaction(User) do
  # ...
end
```

This is particularly useful when working with multiple databases in ActiveRecord.

You can also provide default transaction options when including the extension:

```ruby
include Dry::Operation::Extensions::ActiveRecord[isolation: :serializable]
```

You can override these options at runtime:

```ruby
transaction(isolation: :serializable) do
  # ...
end
```

⚠️  Warning: The `:requires_new` option for nested transactions is not yet fully supported.
