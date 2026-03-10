---
title: Migrating from Dry Transaction
layout: gem-single
name: dry-operation
---

Dry Operation is the successor to [Dry Transaction](/gems/dry-transaction). While both libraries support Railway Oriented Programming, Dry Operation offers a more flexible approach.

Dry Operation provides an alternative to every Dry Transaction feature, allowing you to migrate to Dry Operation for all your transaction classes.

## Migrating a simple transaction

Move your class-level steps into your operation's `#call` method. Use the return values of each step to prepare the input for the next step, which you can pass explicitly. This allows you to adjust the input values between steps, or use steps with different signatures.

**Dry Transaction**
```ruby
class CreateUser
  include Dry::Transaction

  step :validate
  step :create

  private

  def validate(input)
    # returns Success(valid_data) or Failure(validation)
  end

  def create(input)
    # returns Success(user)
  end
end
```

**Dry Operation**
```ruby
class CreateUser < Dry::Operation
  def call(input)
    attrs = step validate(input)
    user = step create(attrs)
    user
  end

  private

  def validate(input)
    # returns Success(valid_data) or Failure(validation)
  end

  def create(attrs)
    # returns Success(user)
  end
end
```

Usage of both is identical. Both return a `Success` or `Failure` from their `#call` method.

```ruby
result = CreateUser.new.call(name: "Jane", email: "jane@example.com")
result.success?
```

## Step Adapters

Dry Transaction's step adapters (`map`, `try`, `check`, `tee`) worked as a class-level DSL to act on step return values. With Dry Operation, you can use either plain Ruby, or additional monads from [Dry Monads](/gems/dry-monads).

### `map` - wrapping raw values

Wrap the value in `Success()`.

**Dry Transaction**
```ruby
class CreateUser
  include Dry::Transaction

  map :process # Wraps return value in Success
  step :create
end
```

**Dry Operation**
```ruby
class CreateUser < Dry::Operation
  def call(input)
    attrs = step process(input) 
    user = step create(attrs)
    user
  end

  private

  def process(input)
    # Wrap the value in Success()
    Success(input.merge(processed: true))
  end

  def create(attrs)
    # Returns Success/Failure
  end
end
```

### `try` - exception handling

Use your own `begin`/`rescue`, or the `Try` monad.

**Dry Transaction**
```ruby
class FetchData
  include Dry::Transaction

  try :fetch, catch: NetworkError
  step :process
end
```

**Dry Operation**
```ruby
require "dry/operation/extensions/monads"

class FetchData < Dry::Operation
  include Dry::Monads[:try]

  def call(input)
    data = step fetch(input)
    result = step process(data)
    result
  end

  private

  def fetch(input)
    # Try automatically converts to Result
    Try[NetworkError] { HTTP.get("/data/#{input}") }
    
    # Alternatively, use plain begin/rescue
    # 
    # begin
    #   Success(HTTP.get("/data/#{input}"))
    # rescue NetworkError => e
    #   Failure(e)
    # end    
  end

  def process(data)
    Success(data.transform)
  end
end
```

### `check` - boolean validation

Return `Failure()` from simple conditionals, or use the `Maybe` monad.

**Dry Transaction**
```ruby
class CreateUser
  include Dry::Transaction

  check :valid?
  step :create
end
```

**Dry Operation**

Using conditionals:
```ruby
class CreateUser < Dry::Operation
  def call(input)
    # Check the conditional and return a Failure.
    return Failure(:invalid) unless valid?(input)
    
    user = step create(input)
    user
  end

  private

  def valid?(input)
    # Returns boolean
    input[:name] && input[:email]
  end

  def create(input)
    Success(User.new(input))
  end
end
```

Use `Maybe` if a `nil` should result in a failure:
```ruby
class CreateUser < Dry::Operation
  include Dry::Monads[:maybe]

  def call(input)
    # When given a nil, `Maybe` becomes a `None`, which converts to `Failure`.
    # 
    # Non-nil values become `Some` and convert to `Success`.
    name = step Maybe(input[:name])
    email = step Maybe(input[:email])
    
    user = step create(name: name, email: email)
    user
  end
end
```

### `tee` - side effects

Just run some Ruby code between steps.

**Dry Transaction**
```ruby
class CreateUser
  include Dry::Transaction

  step :create
  tee :notify # Runs for side effects, passes input through
end
```

**Dry Operation**
```ruby
class CreateUser < Dry::Operation
  def call(input)
    user = step create(input)
    
    # Just call the method directly for side effects
    notify(user)
    
    user # Return what you want
  end

  private

  def create(input)
    Success(User.new(input))
  end

  def notify(user)
    # Side effect - return value doesn't matter
    Mailer.send_welcome(user)
  end
end
```

## Running external steps (containers and dependency injection)

For standalone usage, instead of using a container to supply external steps, make those steps available as instance methods. You can use dependency injection if you want to accept steps from outside the class, or simply expose them as private methods.

If you're working within a Hanami app, use the `Deps` mixin.

**Dry Transaction**
```ruby
class Container
  extend Dry::Container::Mixin

  register "users.validate" do
    Users::Validate.new
  end

  register "users.create" do
    Users::Create.new
  end
end

class CreateUser
  include Dry::Transaction(container: Container)

  step :validate, with: "users.validate"
  step :create, with: "users.create"
end
```

**Dry Operation**

In a Hanami app:
```ruby
class CreateUser < Dry::Operation
  # Use this same approach when using Dry AutoInject
  include Deps[validate: "users.validate", create: "users.create"]

  def call(input)
    attrs = step validate.call(input)
    user = step create.call(attrs)
    user
  end
end
```

Or standalone:
```ruby
class CreateUser < Dry::Operation
  def initialize(validate: Users::Validate.new, create: Users::Create.new)
    @validate = validate
    @create = create
  end

  def call(input)
    attrs = step @validate.call(input)
    user = step @create.call(attrs)
    user
  end
  
  private
  
  # If DI isn't your jam, expose these as methods, or however you like. It's just Ruby!
  # 
  # def call(input)
  #   attrs = step validate.call(input)
  #   # ...
  # end
  # 
  # def validate
  #   @validate ||= Users::Validate.new
  # end
end
```

## Passing step arguments

Because Dry Transaction used a strict output→input flow for step arguments, your only option to adjust step arguments was to use the special `#with_step_args` method, which had to be called from the outside to add additional step arguments after a leading input argument.

With Dry Operation, you can supply arguments in any arrangement directly inside your `#call` method.

**Dry Transaction**
```ruby
class CreateUser
  include Dry::Transaction

  step :validate
  step :create
  tee :notify
  
  # ...
end

create_user = CreateUser.new
create_user
  .with_step_args(
    create: [account_id: 123],
    notify: ["admin@example.com"]
  )
  .call(name: "Jane")
```

**Dry Operation**
```ruby
class CreateUser < Dry::Operation
  def call(input, account_id:, notification_recipient:)
    attrs = step validate(input)
    user = step create(**attrs, account_id:)
    notify(user, notification_recipient:)
    user
  end

  # ...
end
```

## Step notifications

Implement your own pub/sub using a gem like Dry Events (or many others), or just with plain Ruby. Use the `#on_failure` hook to publish events on failures.

**Dry Transaction**
```ruby
class CreateUser
  include Dry::Transaction

  step :validate
  step :create
end

module UserCreationListener
  extend self

  def on_step(event)
    # Called when step starts
  end

  def on_step_succeeded(event)
    # Called when step succeeds
  end

  def on_step_failed(event)
    # Called when step fails
  end
end

create_user = CreateUser.new
create_user.subscribe(create: UserCreationListener)
```

**Dry Operation**

Using [Dry Events](/gems/dry-events):
```ruby
require "dry/events/publisher"

class CreateUser < Dry::Operation
  include Dry::Events::Publisher[:user_operations]

  def call(input)
    attrs = step validate(input)
    publish("step.succeeded", step: :validate, result: attrs)

    user = step create(attrs)
    publish("step.succeeded", step: :create, result: user)

    user
  end

  private

  def on_failure(failure, step_name)
    publish("step.failed", step: step_name, failure: failure)
  end
end

create_user = CreateUser.new
create_user.subscribe(listener)
```

## Around steps (database transactions)

Dry Transaction uses `around` steps to wrap all subsequent steps. This is typically used to catch failed steps and rollback a database transaction. With Dry Operation, you can use dedicated database extensions.

**Dry Transaction**

```ruby
class CreateUser
  include Dry::Transaction(container: Container)

  around :transaction, with: "transaction"
  step :create_user, with: "users.create"
  step :create_account, with: "accounts.create"
end
```

**Dry Operation**

Using the database extensions:
```ruby
require "dry/operation/extensions/active_record"

class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::ActiveRecord

  def call(input)
    user = transaction do
      new_user = step create_user(input)
      step create_account(new_user)
      new_user
    end
    user
  end
end
```

Available transaction extensions:

- `Dry::Operation::Extensions::ActiveRecord`
- `Dry::Operation::Extensions::Sequel`
- `Dry::Operation::Extensions::ROM`

## Result matching

Both Dry Operation and Dry Transaction return a `Result`, whose API you can use in both cases.

Dry Operation does not support Dry Transaction's match block style. Instead, use Dry Monads pattern matching with `case`/`in`, and return `Failure` structures with identifiers.

**Dry Transaction**
```ruby
CreateUser.new.call(input) do |m|
  m.success { |user| puts "Created: #{user.name}" }
  m.failure(:validate) { |errors| puts "Validation failed: #{errors}" }
  m.failure { |error| puts "Error: #{error}" }
end
```

**Dry Operation**
```ruby
class CreateUser < Dry::Operation
  def call(input)
    attrs = step validate(input)
    user = step create(attrs)
    user
  end

  private

  def validate(input)
    errors = do_the_validation
    
    if errors.any?
      Failure[:validate, errors]
    else
      Success(input)
    end
  end

  def create(attrs)
    # Return success or failure
  end
end
```

Then use pattern matching to handle the result:

```ruby
case CreateUser.new.call(input)
in Success(user)
  puts "User created: #{user.name}"
in Failure[:validate, errors]
  puts "Validation failed: #{errors}"
in Failure(error)
  puts "Failure: #{error}"
end
```

See the [pattern matching documentation](/gems/dry-monads/1.3/pattern-matching/) for more details.
