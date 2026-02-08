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

        params user_contract

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

        params shared_contract

        def call(input)
          "Audited: #{input[:action]} by user #{input[:user_id]}"
        end
      end

      log_operation = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params shared_contract

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
end
