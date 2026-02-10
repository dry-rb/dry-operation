---
title: Migrating from dry-transaction
layout: gem-single
name: dry-operation
---

This guide will help you migrate from dry-transaction to dry-operation. While both libraries share similar goals around Railway Oriented Programming, dry-operation takes a different approach by embracing instance-level operations and Ruby's natural expressiveness.

## Key Differences

### Philosophy

**dry-transaction** uses a class-level DSL to define a pipeline of steps:

```ruby
class CreateUser
  include Dry::Transaction

  step :validate
  step :create
  step :notify
end
```

**dry-operation** uses instance-level Ruby code inside methods:

```ruby
class CreateUser < Dry::Operation
  def call(input)
    attrs = step validate(input)
    user = step create(attrs)
    step notify(user)
    user
  end
end
```

### Key Changes

- **Class-level DSL → Instance-level code**: Write regular Ruby in `#call` instead of declaring steps
- **Implicit flow → Explicit flow**: You control data flow with variables and return values
- **Container injection → Direct instantiation**: Operations are regular Ruby objects
- **Step adapters → Monads + Ruby**: Use dry-monads directly and standard Ruby patterns

## Basic Migration

### Simple Transaction

**dry-transaction:**

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

# Usage
result = CreateUser.new.call(name: "Jane", email: "jane@example.com")
```

**dry-operation:**

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

# Usage (identical)
result = CreateUser.new.call(name: "Jane", email: "jane@example.com")
```

### Handling Results

Result handling is identical - both return `Success` or `Failure` from dry-monads:

```ruby
# Works the same in both
result.success? # => true/false
result.failure? # => true/false
result.value!   # => unwrapped value or raises

# Pattern matching
case result
in Success(user)
  puts "Created #{user.name}"
in Failure(error)
  puts "Error: #{error}"
end

# Match block (dry-transaction style)
result.value_or { |error| puts "Failed: #{error}" }
```

## Step Adapters

dry-transaction provided step adapters (`map`, `try`, `check`, `tee`) as a class-level DSL. In dry-operation, you use dry-monads directly and standard Ruby patterns.

### `map` - Wrapping raw values

**dry-transaction:**

```ruby
class CreateUser
  include Dry::Transaction

  map :process      # Wraps return value in Success
  step :create
end
```

**dry-operation:**

```ruby
class CreateUser < Dry::Operation
  def call(input)
    attrs = step Success(process(input))  # Explicit wrapping
    user = step create(attrs)
    user
  end

  private

  def process(input)
    # Returns raw value
    input.merge(processed: true)
  end

  def create(attrs)
    # Returns Success/Failure
  end
end
```

### `try` - Exception handling

**dry-transaction:**

```ruby
class FetchData
  include Dry::Transaction

  try :fetch, catch: NetworkError
  step :process
end
```

**dry-operation:**

```ruby
require "dry/operation/extensions/monads"

class FetchData < Dry::Operation
  include Dry::Operation::Extensions::Monads

  def call(input)
    # Try monad automatically converts to Result
    data = step Try { fetch(input) }
    result = step process(data)
    result
  end

  private

  def fetch(input)
    # May raise exception - Try catches it
    HTTP.get("/data/#{input}")
  end

  def process(data)
    Success(data.transform)
  end
end
```

Or catch specific exceptions:

```ruby
def call(input)
  data = step Try[NetworkError, TimeoutError] { fetch(input) }
  # ...
end
```

### `check` - Boolean validation

**dry-transaction:**

```ruby
class CreateUser
  include Dry::Transaction

  check :valid?     # Returns Success(input) if truthy
  step :create
end
```

**dry-operation:**

```ruby
class CreateUser < Dry::Operation
  def call(input)
    # Use early return for validation
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

Or use Maybe monad:

```ruby
require "dry/operation/extensions/monads"

class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Monads

  def call(input)
    # Maybe converts None to Failure, Some to Success
    name = step Maybe(input[:name])
    email = step Maybe(input[:email])
    
    user = step create(name: name, email: email)
    user
  end
end
```

### `tee` - Side effects

**dry-transaction:**

```ruby
class CreateUser
  include Dry::Transaction

  step :create
  tee :notify       # Runs for side effects, passes input through
end
```

**dry-operation:**

```ruby
class CreateUser < Dry::Operation
  def call(input)
    user = step create(input)
    
    # Just call the method directly for side effects
    notify(user)
    
    user  # Return what you want
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

## Container and Dependency Injection

### External Operations via Container

**dry-transaction:**

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

**dry-operation:**

dry-operation doesn't have built-in container support. Instead, use standard dependency injection:

```ruby
class CreateUser < Dry::Operation
  def initialize(validator: Users::Validate.new, creator: Users::Create.new)
    @validator = validator
    @creator = creator
    super()
  end

  def call(input)
    attrs = step @validator.call(input)
    user = step @creator.call(attrs)
    user
  end
end

# With dry-system/dry-auto_inject
class CreateUser < Dry::Operation
  include Import["users.validate", "users.create"]

  def call(input)
    attrs = step validate.call(input)
    user = step create.call(attrs)
    user
  end
end
```

### Injecting Operations at Runtime

**dry-transaction:**

```ruby
create_user = CreateUser.new(
  validate: -> input { Success(input) },
  create: -> input { Success(User.new(input)) }
)
```

**dry-operation:**

```ruby
create_user = CreateUser.new(
  validator: -> input { Success(input) },
  creator: -> input { Success(User.new(input)) }
)
```

## Step Arguments

### Passing Additional Arguments

**dry-transaction:**

```ruby
class CreateUser
  include Dry::Transaction

  step :validate
  step :create
  step :notify

  private

  def create(input, account_id:)
    # ...
  end

  def notify(user, recipient)
    # ...
  end
end

create_user = CreateUser.new
create_user
  .with_step_args(
    create: [account_id: 123],
    notify: ["admin@example.com"]
  )
  .call(name: "Jane")
```

**dry-operation:**

```ruby
class CreateUser < Dry::Operation
  attr_reader :account_id, :notification_recipient

  def initialize(account_id: nil, notification_recipient: nil)
    @account_id = account_id
    @notification_recipient = notification_recipient
    super()
  end

  def call(input)
    attrs = step validate(input)
    user = step create(attrs, account_id: account_id)
    notify(user, notification_recipient) if notification_recipient
    user
  end

  private

  def validate(input)
    # ...
  end

  def create(input, account_id:)
    # ...
  end

  def notify(user, recipient)
    # ...
  end
end

create_user = CreateUser.new(
  account_id: 123,
  notification_recipient: "admin@example.com"
)
create_user.call(name: "Jane")
```

## Step Notifications

**dry-transaction:**

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

**dry-operation:**

dry-operation doesn't have built-in pub/sub. Use dry-events directly:

```ruby
require "dry/events/publisher"

class CreateUser < Dry::Operation
  include Dry::Events::Publisher[:user_operations]

  def call(input)
    publish("step.started", step: :validate, input: input)
    attrs = step validate(input)
    publish("step.succeeded", step: :validate, result: attrs)

    publish("step.started", step: :create, input: attrs)
    user = step create(attrs)
    publish("step.succeeded", step: :create, result: user)

    user
  rescue => e
    publish("step.failed", step: current_step, error: e)
    raise
  end
end

create_user = CreateUser.new
create_user.subscribe(listener)
```

Or use instrumentation/logging directly:

```ruby
class CreateUser < Dry::Operation
  attr_reader :logger

  def initialize(logger: Logger.new(STDOUT))
    @logger = logger
    super()
  end

  def call(input)
    logger.info "Starting validation"
    attrs = step validate(input)
    logger.info "Validation succeeded"

    logger.info "Creating user"
    user = step create(attrs)
    logger.info "User created: #{user.id}"

    user
  end
end
```

## Around Steps (Database Transactions)

**dry-transaction:**

```ruby
class CreateUser
  include Dry::Transaction(container: Container)

  around :transaction, with: "transaction"
  step :create_user, with: "users.create"
  step :create_account, with: "accounts.create"
end
```

**dry-operation:**

Use the database extensions:

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

Or use database transactions directly:

```ruby
class CreateUser < Dry::Operation
  def call(input)
    result = nil
    ActiveRecord::Base.transaction do
      user = step create_user(input)
      step create_account(user)
      result = user
    rescue => e
      raise ActiveRecord::Rollback
    end
    result
  end
end
```

## Result Matching

Result matching works the same way in both libraries since they both use dry-monads:

```ruby
# Both support this syntax
result.value_or { |error| handle_error(error) }

# Match blocks (dry-transaction style)
CreateUser.new.call(input) do |m|
  m.success { |user| puts "Created: #{user.name}" }
  m.failure(:validate) { |errors| puts "Validation failed: #{errors}" }
  m.failure { |error| puts "Error: #{error}" }
end
```

In dry-operation, you can also use the `#on_failure` hook:

```ruby
class CreateUser < Dry::Operation
  def call(input)
    attrs = step validate(input)
    user = step create(attrs)
    user
  end

  def on_failure(failure_value, method_name)
    logger.error "Failed at #{method_name}: #{failure_value}"
  end
end
```

## Testing

### dry-transaction

```ruby
RSpec.describe CreateUser do
  subject(:transaction) { described_class.new }

  it "creates a user" do
    result = transaction.call(name: "Jane", email: "jane@example.com")
    expect(result).to be_success
    expect(result.value!).to be_a(User)
  end

  it "handles validation errors" do
    result = transaction.call(name: "", email: "")
    expect(result).to be_failure
  end

  # Test with injected operations
  it "can inject test doubles" do
    validator = -> input { Success(input) }
    transaction = described_class.new(validate: validator)
    
    result = transaction.call(name: "Jane", email: "jane@example.com")
    expect(result).to be_success
  end
end
```

### dry-operation

```ruby
RSpec.describe CreateUser do
  subject(:operation) { described_class.new }

  it "creates a user" do
    result = operation.call(name: "Jane", email: "jane@example.com")
    expect(result).to be_success
    expect(result.value!).to be_a(User)
  end

  it "handles validation errors" do
    result = operation.call(name: "", email: "")
    expect(result).to be_failure
  end

  # Test with injected dependencies
  it "can inject test doubles" do
    validator = instance_double("Validator", call: Success({name: "Jane"}))
    creator = instance_double("Creator", call: Success(User.new))
    operation = described_class.new(validator: validator, creator: creator)
    
    result = operation.call(name: "Jane", email: "jane@example.com")
    expect(result).to be_success
  end
end
```

## Migration Checklist

When migrating from dry-transaction to dry-operation:

1. ✅ Change `include Dry::Transaction` to inherit from `Dry::Operation`
2. ✅ Move step declarations into a `#call` method with instance-level code
3. ✅ Replace `map` with explicit `Success()` wrapping
4. ✅ Replace `try` with `Try { }` monad (include Monads extension)
5. ✅ Replace `check` with early returns or Maybe monad
6. ✅ Replace `tee` with direct method calls
7. ✅ Replace container resolution with dependency injection in `#initialize`
8. ✅ Replace `around` steps with database transaction extensions
9. ✅ Replace step notifications with direct logging or dry-events
10. ✅ Update tests to use constructor injection for test doubles

## Complete Example

### Before (dry-transaction)

```ruby
class CreateUser
  include Dry::Transaction(container: Container)

  map :process
  try :validate, catch: ValidationError
  around :transaction, with: "db.transaction"
  step :create, with: "users.create"
  step :assign_role, with: "users.assign_role"
  tee :notify, with: "users.notify"
end
```

### After (dry-operation)

```ruby
require "dry/operation/extensions/monads"
require "dry/operation/extensions/active_record"

class CreateUser < Dry::Operation
  include Dry::Operation::Extensions::Monads
  include Dry::Operation::Extensions::ActiveRecord
  include Import["users.create", "users.assign_role", "users.notify"]

  def call(input)
    # Explicit wrapping instead of map
    attrs = step Success(process(input))
    
    # Try monad for exception handling
    validated = step Try[ValidationError] { validate(attrs) }
    
    # Database transaction wrapping multiple steps
    user = transaction do
      new_user = step create.call(validated)
      step assign_role.call(new_user)
      new_user
    end
    
    # Direct call for side effects instead of tee
    notify.call(user)
    
    user
  end

  private

  def process(input)
    input.merge(processed_at: Time.now)
  end

  def validate(attrs)
    # May raise ValidationError
    Validator.validate!(attrs)
  end
end
```

## Summary

dry-operation gives you:
- 💪 **Full Ruby power** - Write regular Ruby code instead of DSL
- 🎯 **Explicit flow** - See exactly how data flows through your operation
- 🧪 **Standard testing** - Use constructor injection for test doubles
- 🔌 **Flexibility** - Mix in only the extensions you need
- 🚀 **Simplicity** - Fewer abstractions to learn

The trade-off is that you write slightly more code, but it's clearer, more explicit, and leverages Ruby's natural expressiveness.