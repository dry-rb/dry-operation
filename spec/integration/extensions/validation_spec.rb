# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::Validation do
  include Dry::Monads[:result]

  describe "validating operation inputs" do
    it "validates params and allows operation to proceed on success" do
      create_user = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
          required(:email).filled(:string)
          optional(:age).maybe(:integer)
        end

        def call(input)
          user = step create_user_record(input)
          step send_welcome_email(user)
          user
        end

        private

        def create_user_record(attrs)
          Success(attrs.merge(id: 1))
        end

        def send_welcome_email(_user)
          Success(true)
        end
      end

      result = create_user.new.call(name: "John Doe", email: "john@example.com", age: 25)

      expect(result).to be_success
      expect(result.value!).to eq(id: 1, name: "John Doe", email: "john@example.com", age: 25)
    end

    it "returns validation failure before executing operation logic" do
      executed_steps = []

      create_user = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
          required(:email).filled(:string)
        end

        define_method(:call) do |input|
          executed_steps << :call_started
          user = step create_user_record(input)
          executed_steps << :user_created
          user
        end

        define_method(:create_user_record) do |attrs|
          executed_steps << :create_user_record
          Success(attrs.merge(id: 1))
        end
      end

      result = create_user.new.call(name: "", email: "invalid")

      expect(result).to be_failure
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result).to be_a(Dry::Validation::Result)
      expect(validation_result.errors.to_h).to eq(name: ["must be filled"])
      expect(executed_steps).to be_empty
    end

    it "coerces input values according to params schema" do
      calculate = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:x).value(:integer)
          required(:y).value(:integer)
        end

        def call(input)
          input[:x] + input[:y]
        end
      end

      result = calculate.new.call(x: "10", y: "20")

      expect(result).to be_success
      expect(result.value!).to eq(30)
    end
  end

  describe "with schema (no coercion)" do
    it "validates without coercing types" do
      operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        schema do
          required(:name).filled(:string)
          required(:age).filled(:integer)
        end

        def call(input)
          input
        end
      end

      result = operation.new.call(name: "Alice", age: 25)
      expect(result).to be_success
      expect(result.value!).to eq(name: "Alice", age: 25)

      result = operation.new.call(name: "Alice", age: "25")
      expect(result).to be_failure
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result.errors.to_h[:age]).to be_present
    end
  end

  describe "with nested schemas" do
    it "validates nested structures" do
      create_order = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:customer).hash do
            required(:name).filled(:string)
            required(:email).filled(:string)
          end
          required(:items).array(:hash) do
            required(:product_id).filled(:integer)
            required(:quantity).filled(:integer)
          end
        end

        def call(input)
          input
        end
      end

      result = create_order.new.call(
        customer: {name: "John", email: "john@example.com"},
        items: [
          {product_id: 1, quantity: 2},
          {product_id: 2, quantity: 1}
        ]
      )

      expect(result).to be_success
    end

    it "returns detailed validation errors for nested structures" do
      create_order = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:customer).hash do
            required(:name).filled(:string)
            required(:email).filled(:string)
          end
        end

        def call(input)
          input
        end
      end

      result = create_order.new.call(customer: {name: "", email: ""})

      expect(result).to be_failure
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result).to be_a(Dry::Validation::Result)
      expect(validation_result.errors.to_h[:customer]).to include(:name, :email)
    end
  end

  describe "with custom methods via operate_on" do
    it "validates params for custom wrapped methods" do
      processor = Class.new(Dry::Operation) do
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

      instance = processor.new

      result = instance.process(value: "hello")
      expect(result).to eq(Success("HELLO"))

      result = instance.transform(value: "WORLD")
      expect(result).to eq(Success("world"))

      result = instance.process(value: "")
      expect(result).to be_failure
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result.errors.to_h).to eq(value: ["must be filled"])
    end
  end

  describe "with pre-built contract classes" do
    it "accepts a pre-defined Contract class" do
      user_contract = Class.new(Dry::Validation::Contract) do
        params do
          required(:name).filled(:string)
          required(:email).filled(:string)
          optional(:age).maybe(:integer)
        end
      end

      create_user = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        contract user_contract

        def call(input)
          input
        end
      end

      result = create_user.new.call(name: "Alice", email: "alice@example.com")
      expect(result).to be_success
      expect(result.value!).to include(name: "Alice", email: "alice@example.com")

      result = create_user.new.call(name: "", email: "invalid")
      expect(result).to be_failure
      expect(result.failure.first).to eq(:invalid)
    end

    it "allows contract class reuse across multiple operations" do
      shared_contract = Class.new(Dry::Validation::Contract) do
        params do
          required(:user_id).filled(:integer)
          required(:action).filled(:string)
        end
      end

      audit_operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        contract shared_contract

        def call(input)
          "Audited: #{input[:action]} by user #{input[:user_id]}"
        end
      end

      log_operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        contract shared_contract

        def call(input)
          "Logged: #{input[:action]} by user #{input[:user_id]}"
        end
      end

      result = audit_operation.new.call(user_id: 1, action: "login")
      expect(result).to be_success
      expect(result.value!).to eq("Audited: login by user 1")

      result = log_operation.new.call(user_id: 2, action: "logout")
      expect(result).to be_success
      expect(result.value!).to eq("Logged: logout by user 2")
    end
  end

  describe "with contract" do
    it "validates with custom rules" do
      create_user = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

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
          input
        end
      end

      result = create_user.new.call(name: "Alice", age: 25)
      expect(result).to be_success

      result = create_user.new.call(name: "Bob", age: 16)
      expect(result).to be_failure
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result.errors.to_h).to eq(age: ["must be 18 or older"])
    end
  end

  describe "with injected contract dependency" do
    it "uses the injected contract instead of class-level one" do
      injected_contract_class = Class.new(Dry::Validation::Contract) do
        params do
          required(:name).filled(:string)
        end
      end

      operation_class = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:email).filled(:string)
        end

        attr_writer :contract

        def call(input)
          input
        end
      end

      instance = operation_class.new
      instance.contract = injected_contract_class.new

      # Uses injected contract (validates :name), not class-level (validates :email)
      result = instance.call(name: "Alice")
      expect(result).to be_success
      expect(result.value!).to eq(name: "Alice")

      result = instance.call(name: "")
      expect(result).to be_failure
      expect(result.failure.first).to eq(:invalid)
    end
  end

  describe "inheritance" do
    it "inherits contract class from parent" do
      base_operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end
      end

      child_operation = Class.new(base_operation) do
        def call(input)
          "Hello, #{input[:name]}!"
        end
      end

      result = child_operation.new.call(name: "Alice")
      expect(result).to be_success
      expect(result.value!).to eq("Hello, Alice!")

      result = child_operation.new.call(name: "")
      expect(result).to be_failure
    end
  end

  describe "validating all keyword arguments" do
    it "passes through positional arguments untouched" do
      update_user = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end

        def call(id, name:)
          {id:, name:}
        end
      end

      result = update_user.new.call("123", name: "Alice")

      expect(result).to eq(Success(id: "123", name: "Alice"))
    end

    it "does not validate a positional hash" do
      operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          optional(:name).filled(:string)
        end

        def call(input)
          input
        end
      end

      expect(operation.new.call({name: ""})).to eq(Success(name: ""))
    end
  end

  describe "validating a single keyword argument with for:" do
    let(:update_user) {
      Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params(for: :attrs) do
          required(:name).filled(:string)
          optional(:age).value(:integer)
        end

        def call(id, attrs:, notify: false)
          {id:, attrs:, notify:}
        end
      end
    }

    it "validates the keyword argument's value, passing through other arguments untouched" do
      result = update_user.new.call(123, attrs: {name: "Alice", age: "30", admin: true}, notify: "yes")

      expect(result).to eq(Success(id: 123, attrs: {name: "Alice", age: 30}, notify: "yes"))
    end

    it "returns a failure when the keyword argument's value is invalid" do
      result = update_user.new.call(123, attrs: {name: ""})

      expect(result).to be_failure
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result.errors.to_h).to eq(name: ["must be filled"])
    end

    it "leaves a missing keyword argument to the method's own signature" do
      expect { update_user.new.call(123) }
        .to raise_error(ArgumentError, /missing keyword: :attrs/)
    end

    it "is supported by contract and schema" do
      user_contract = Class.new(Dry::Validation::Contract) do
        params do
          required(:name).filled(:string)
        end
      end

      with_contract = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        contract user_contract, for: :attrs

        def call(attrs:, notify: false)
          [attrs, notify]
        end
      end

      with_schema = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        schema(for: :attrs) do
          required(:name).filled(:string)
        end

        def call(attrs:, notify: false)
          [attrs, notify]
        end
      end

      [with_contract, with_schema].each do |operation|
        expect(operation.new.call(attrs: {name: "Alice", admin: true}, notify: true))
          .to eq(Success([{name: "Alice"}, true]))
      end
    end

    it "is inherited by subclasses" do
      child = Class.new(update_user)

      expect(child.new.call(1, attrs: {name: "Alice"})).to eq(Success(id: 1, attrs: {name: "Alice"}, notify: false))
    end
  end

  describe "validating a subset of keyword arguments with keys:" do
    let(:authorize) {
      Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params(keys: %i[account_id scope]) do
          required(:account_id).filled(:integer)
          optional(:scope).array(:string)
        end

        def call(code, account_id:, scope: [], notify: false)
          {code:, account_id:, scope:, notify:}
        end
      end
    }

    it "validates the named keyword arguments together, passing through other arguments untouched" do
      result = authorize.new.call("abc", account_id: "1", scope: ["read"], notify: "yes")

      expect(result).to eq(Success(code: "abc", account_id: 1, scope: ["read"], notify: "yes"))
    end

    it "returns a failure when the named keyword arguments are invalid" do
      result = authorize.new.call("abc", scope: ["read"])

      expect(result).to be_failure
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result.errors.to_h).to eq(account_id: ["is missing"])
    end

    it "lets the method's own defaults apply to optional keys that are not given" do
      expect(authorize.new.call("abc", account_id: 1)).to eq(Success(code: "abc", account_id: 1, scope: [], notify: false))
    end
  end

  describe "contract input options" do
    it "raises when both for: and keys: are given" do
      expect {
        Class.new(Dry::Operation) do
          include Dry::Operation::Extensions::Validation

          params(for: :attrs, keys: %i[name]) do
            required(:name).filled(:string)
          end
        end
      }.to raise_error(ArgumentError, "pass either for: or keys:, not both")
    end

    it "raises when an unknown option is given" do
      expect {
        Class.new(Dry::Operation) do
          include Dry::Operation::Extensions::Validation

          params(fro: :attrs) do
            required(:name).filled(:string)
          end
        end
      }.to raise_error(ArgumentError, "unknown keyword: :fro")
    end
  end

  describe "operations taking no input" do
    it "calls a method taking no arguments when no contract is defined" do
      operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        def call
          step build_thing
        end

        private

        def build_thing
          Success(:thing)
        end
      end

      expect(operation.new.call).to eq(Success(:thing))
    end

    it "forwards arguments untouched when no contract is defined" do
      operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        def call(input, extra: nil)
          [input, extra]
        end
      end

      expect(operation.new.call(:input, extra: :extra)).to eq(Success([:input, :extra]))
    end

    it "calls a method taking no arguments when the contract validates an empty input" do
      operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          optional(:name).filled(:string)
        end

        def call
          step build_thing
        end

        private

        def build_thing
          Success(:thing)
        end
      end

      expect(operation.new.call).to eq(Success(:thing))
    end

    it "fails validation when a method taking no arguments has a contract requiring input" do
      operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end

        def call
          Success(:thing)
        end
      end

      result = operation.new.call

      expect(result).to be_failure
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result.errors.to_h).to eq(name: ["is missing"])
    end

    it "raises when input is given to a method that takes no arguments" do
      operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          optional(:name).filled(:string)
        end

        def call
          Success(:thing)
        end
      end

      expect { operation.new.call(name: "Alice") }
        .to raise_error(ArgumentError, /wrong number of arguments/)
    end

    it "validates an empty input for a method taking only keyword arguments" do
      operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          optional(:name).filled(:string)
        end

        def call(name: "anonymous")
          name
        end
      end

      expect(operation.new.call).to eq(Success("anonymous"))
      expect(operation.new.call(name: "Alice")).to eq(Success("Alice"))
    end
  end
end
