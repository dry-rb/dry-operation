---
title: Extensions
layout: gem-single
name: dry-operation
---

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

By default, the `:default` gateway will be used. You can specify a different gateway either when including the extension:

```ruby
include Dry::Operation::Extensions::ROM[gateway: :my_gateway]
```

Or at runtime:

```ruby
transaction(gateway: :my_gateway) do
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

### Params

The `Params` extension adds input validation support to your operations using [dry-validation](https://dry-rb.org/gems/dry-validation/). When an operation is called, the input will be automatically validated against the defined rules before the operation logic executes. If validation fails, the operation returns a `Failure` with detailed error information without executing the operation body.

Make sure you have dry-validation installed:

```ruby
gem "dry-validation"
```

Require and include the extension in your operation class, then define validation rules using the `params` class method:

```ruby
require "dry/operation/extensions/params"

class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Params

  params do
    required(:name).filled(:string)
    required(:email).filled(:string)
    optional(:age).maybe(:integer)
  end

  def call(input)
    user = step create_user(input)
    step notify(user)
    user
  end

  # ...
end
```

When validation succeeds, the operation receives the validated and coerced input:

```ruby
result = CreateUser.new.call(name: "Alice", email: "alice@example.com", age: "25")
# => Success(user) with age coerced to integer 25
```

When validation fails, the operation returns a `Failure` tagged with `:invalid_params` and the validation errors, without executing any of the operation's steps:

```ruby
result = CreateUser.new.call(name: "", email: "invalid")
# => Failure[:invalid_params, {name: ["must be filled"]}]
```

#### Using params classes

You can also pass a pre-defined params class to `params` instead of a block, which is useful for reusing validation rules across multiple operations:

```ruby
class UserParams < Dry::Operation::Extensions::Params::Params
  params do
    required(:name).filled(:string)
    required(:email).filled(:string)
    optional(:age).maybe(:integer)
  end
end

class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Params

  params UserParams

  def call(input)
    user = step create_user(input)
    step notify(user)
    user
  end

  # ...
end

class UpdateUser < Dry::Operation
  include Dry::Operation::Extensions::Params

  params UserParams

  def call(input)
    # ...
  end
end
```

#### Using contract for custom validation rules

For more complex validation scenarios, use the `contract` method which provides access to the full dry-validation contract API, including custom rules:

```ruby
class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Params

  contract do
    params do
      required(:name).filled(:string)
      required(:age).filled(:integer)
    end

    rule(:age) do
      key.failure("must be 18 or older") if value < 18
    end
  end

  def call(input)
    # ...
  end
end
```

#### Custom wrapped methods

The `params` extension works seamlessly with custom wrapped methods when using `.operate_on`:

```ruby
class ProcessData < Dry::Operation
  include Dry::Operation::Extensions::Params

  operate_on :process, :transform

  params do
    required(:value).filled(:string)
  end

  def process(input)
    input[:value].upcase
  end

  def transform(input)
    input[:value].downcase
  end
end
```

#### Inheritance

Params classes are inherited by subclasses, allowing you to build operation hierarchies with shared validation rules.
