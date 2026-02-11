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

### Validation

The `Validation` extension adds input validation support to your operations using [dry-validation](https://dry-rb.org/gems/dry-validation/). When an operation is called, the input will be automatically validated against the defined rules before the operation logic executes. If validation fails, the operation returns a `Failure` with detailed error information without executing the operation body.

Make sure you have dry-validation installed:

```ruby
gem "dry-validation"
```

Require and include the extension in your operation class, then define validation rules using the `contract` class method:

```ruby
require "dry/operation/extensions/validation"

class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Validation

  contract do
    params do
      required(:name).filled(:string)
      required(:email).filled(:string)
      optional(:age).maybe(:integer)
    end

    rule(:age) do
      key.failure("must be 18 or older") if value && value < 18
    end
  end

  def call(input)
    user = step create_user(input)
    step notify(user)
    user
  end

  # ...
end
```

When validation succeeds, the operation receives the validated input:

```ruby
result = CreateUser.new.call(name: "Alice", email: "alice@example.com", age: "25")
# => Success(user) with age coerced to integer 25 and validated by the age rule
```

When validation fails, the operation returns a `Failure` tuple containing `:invalid` and the validation result, and does not execute any of the operation's steps.

```ruby
result = CreateUser.new.call(name: "", email: "invalid")
# => Failure[:invalid, #<Dry::Validation::Result ...>]
```

#### Input arguments and validation

The validation contract receives the input from your operation's wrapped method (typically `#call`). This can be provided as either a hash argument or keyword arguments:

```ruby
# Hash argument
result = CreateUser.new.call({name: "Alice", email: "alice@example.com", age: 25})

# Keyword arguments
result = CreateUser.new.call(name: "Alice", email: "alice@example.com", age: 25)
```

When using keyword arguments, any keywords that exist in your method signature but are not present in the validation output will still be passed through. This allows you to mix validated input with method-specific parameters:

```ruby
class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Validation

  contract do
    params do
      required(:name).filled(:string)
      required(:email).filled(:string)
    end
  end

  def call(name:, email:, notify: true)
    # `notify` is passed through even though it's not in the contract
    user = step create_user(name: name, email: email)
    step send_notification(user) if notify
    user
  end

  # ...
end
```

#### Using `schema` and `params` blocks

For simpler validation scenarios where you don't need custom rules, you can use `params` or `schema` blocks directly instead of `contract`:

The `params` method provides validation with type coercion for HTTP params:

```ruby
class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Validation

  params do
    required(:name).filled(:string)
    required(:email).filled(:string)
    optional(:age).maybe(:integer)
  end

  def call(input)
    # input[:age] will be coerced from "25" to 25
    user = step create_user(input)
    step notify(user)
    user
  end

  # ...
end
```

The `schema` method provides validation without type coercion:

```ruby
class ProcessData < Dry::Operation
  include Dry::Operation::Extensions::Validation

  schema do
    required(:name).filled(:string)
    required(:age).filled(:integer)
  end

  def call(input)
    # input[:age] must already be an integer; "25" would fail validation
    # ...
  end
end
```

#### Using contract classes

You can also pass a contract class to `contract`, instead of a block. This is useful for reusing validation rules across multiple operations:

```ruby
class UserContract < Dry::Validation::Contract
  params do
    required(:name).filled(:string)
    required(:email).filled(:string)
    optional(:age).maybe(:integer)
  end
end

class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Validation

  contract UserContract

  def call(input)
    user = step create_user(input)
    step notify(user)
    user
  end

  # ...
end

class UpdateUser < Dry::Operation
  include Dry::Operation::Extensions::Validation

  contract UserContract

  def call(input)
    # ...
  end
end
```

#### Injected contracts

You can also provide a contract instance via dependency injection. Make your contract available as  a `#contract` method or `@contract` instance variable:

```ruby
class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Validation

  def initialize(contract:)
    @contract = contract
    super()
  end

  def call(input)
    # ...
  end
end
```

#### Validating custom wrapped methods

Validation applies to any custom wrapped methods configured with `.operate_on`:

```ruby
class ProcessData < Dry::Operation
  include Dry::Operation::Extensions::Validation

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

Validation contracts are inherited by subclasses, allowing you to build operation hierarchies with shared validation rules.
