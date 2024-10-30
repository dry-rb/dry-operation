---
title: Extensions
layout: gem-single
name: dry-operation
---

### ROM

The `ROM` extension adds transaction support to your operations when working with [`rom-rb.org`](https://rom-rb.org). When a step returns a `Failure`, the transaction will automatically roll back, ensuring data consistency.

First, make sure you have `rom-sql` installed:

```ruby
gem 'rom-sql'
```

Require and include the extension in your operation class and provide access to the ROM container through a `#rom` method:

```ruby
require 'dry/operation/extensions/rom'

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

The `Sequel` extension provides transaction support for operations using [`sequel` databases](http://sequel.jeremyevans.net). It will automatically roll back the transaction if any step returns a `Failure`.

Make sure you have sequel installed:

```ruby
gem 'sequel'
```

Require and include the extension in your operation class and provide access to the Sequel database object through a `#db` method:

```ruby
require 'dry/operation/extensions/sequel'

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

The `ActiveRecord` extension adds transaction support for operations using [`activerecord`](https://api.rubyonrails.org/classes/ActiveRecord). Like the other database extensions, it will roll back the transaction if any step returns a `Failure`.

Make sure you have activerecord installed:

```ruby
gem 'activerecord'
```

Require and include the extension in your operation class:

```ruby
require 'dry/operation/extensions/active_record'

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

This is particularly useful when working with multiple databases in `ActiveRecord`.

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
