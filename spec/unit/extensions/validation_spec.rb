# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::Validation do
  include Dry::Monads[:result]

  describe ".params" do
    it "creates a Contract class with params validation" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end
      end

      expect(klass._contract_class).to be_a(Class)
      expect(klass._contract_class.superclass).to eq(Dry::Validation::Contract)
    end

    it "accepts a pre-built Contract class" do
      contract_class = Class.new(Dry::Validation::Contract) do
        params do
          required(:name).filled(:string)
        end
      end

      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params contract_class
      end

      expect(klass._contract_class).to eq(contract_class)
    end

    it "allows contract class to be inherited by subclasses" do
      parent = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end
      end

      child = Class.new(parent)

      expect(child._contract_class).to eq(parent._contract_class)
    end

    it "allows subclass to override parent contract class" do
      parent = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end
      end

      child = Class.new(parent) do
        params do
          required(:email).filled(:string)
        end
      end

      expect(child._contract_class).not_to eq(parent._contract_class)
    end
  end

  describe ".schema" do
    it "creates a Contract class with schema validation (no coercion)" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        schema do
          required(:name).filled(:string)
        end
      end

      expect(klass._contract_class).to be_a(Class)
      expect(klass._contract_class.superclass).to eq(Dry::Validation::Contract)
    end

    it "accepts a pre-built Contract class" do
      contract_class = Class.new(Dry::Validation::Contract) do
        schema do
          required(:name).filled(:string)
        end
      end

      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        schema contract_class
      end

      expect(klass._contract_class).to eq(contract_class)
    end

    it "does not coerce values" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        schema do
          required(:age).filled(:integer)
        end

        def call(input)
          input
        end
      end

      instance = klass.new
      result = instance.call(age: "25")

      expect(result).to be_a(Dry::Monads::Failure)
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result.errors.to_h[:age]).to be_present
    end
  end

  describe ".contract" do
    it "creates a Contract class with contract validation" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        contract do
          params do
            required(:name).filled(:string)
          end

          rule(:name) do
            key.failure("must be uppercase") unless value.upcase == value
          end
        end
      end

      expect(klass._contract_class).to be_a(Class)
      expect(klass._contract_class.superclass).to eq(Dry::Validation::Contract)
    end

    it "accepts a pre-built Contract class" do
      contract_class = Class.new(Dry::Validation::Contract) do
        params do
          required(:name).filled(:string)
        end
      end

      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        contract contract_class
      end

      expect(klass._contract_class).to eq(contract_class)
    end
  end

  describe "#__validate__" do
    it "returns Success with input when no contract class is defined" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation
      end

      instance = klass.new
      result = instance.send(:__validate__, name: "John")

      expect(result).to eq(Success(name: "John"))
    end

    it "returns Success with validated params when validation passes" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end
      end

      instance = klass.new
      result = instance.send(:__validate__, name: "John")

      expect(result).to eq(Success(name: "John"))
    end

    it "returns Failure with :invalid and the result object when validation fails" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end
      end

      instance = klass.new
      result = instance.send(:__validate__, name: "")

      expect(result).to be_a(Dry::Monads::Failure)
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result).to be_a(Dry::Validation::Result)
      expect(validation_result.errors.to_h).to eq(name: ["must be filled"])
    end

    it "coerces values according to params schema" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:age).value(:integer)
        end
      end

      instance = klass.new
      result = instance.send(:__validate__, age: "25")

      expect(result).to eq(Success(age: 25))
    end

    it "validates contract rules" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        contract do
          params do
            required(:name).filled(:string)
          end

          rule(:name) do
            key.failure("must be uppercase") unless value.upcase == value
          end
        end
      end

      instance = klass.new

      result = instance.send(:__validate__, name: "JOHN")
      expect(result).to eq(Success(name: "JOHN"))

      result = instance.send(:__validate__, name: "john")
      expect(result).to be_a(Dry::Monads::Failure)
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result.errors.to_h).to eq(name: ["must be uppercase"])
    end

    it "uses injected @contract dependency when present" do
      contract_class = Class.new(Dry::Validation::Contract) do
        params do
          required(:name).filled(:string)
        end
      end

      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:email).filled(:string)
        end

        attr_writer :contract
      end

      instance = klass.new
      instance.contract = contract_class.new

      # Should use the injected contract (which validates :name), not the class-level one (which validates :email)
      result = instance.send(:__validate__, name: "John")
      expect(result).to eq(Success(name: "John"))

      result = instance.send(:__validate__, name: "")
      expect(result).to be_a(Dry::Monads::Failure)
    end

    it "lazily instantiates the contract" do
      instantiated = false

      contract_class = Class.new(Dry::Validation::Contract) do
        params do
          required(:name).filled(:string)
        end

        define_method(:initialize) do |*args|
          instantiated = true
          super(*args)
        end
      end

      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params contract_class
      end

      expect(instantiated).to be(false)

      instance = klass.new
      instance.send(:__validate__, name: "John")

      expect(instantiated).to be(true)
    end
  end

  describe "method wrapping" do
    it "validates params before calling the method" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end

        def call(input)
          input
        end
      end

      instance = klass.new
      result = instance.call(name: "John")

      expect(result).to eq(Success(name: "John"))
    end

    it "returns validation failure without executing method body" do
      executed = false

      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end

        define_method(:call) do |input|
          executed = true
          input
        end
      end

      instance = klass.new
      result = instance.call(name: "")

      expect(result).to be_a(Dry::Monads::Failure)
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result.errors.to_h).to eq(name: ["must be filled"])
      expect(executed).to be(false)
    end

    it "works with custom methods specified via operate_on" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        operate_on :process

        params do
          required(:name).filled(:string)
        end

        def process(input)
          input
        end
      end

      instance = klass.new
      result = instance.process(name: "John")

      expect(result).to eq(Success(name: "John"))
    end

    it "validates custom methods when contract is defined before the method" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        operate_on :process

        params do
          required(:name).filled(:string)
        end

        def process(input)
          input
        end
      end

      instance = klass.new
      result = instance.process(name: "")

      expect(result).to be_a(Dry::Monads::Failure)
      failure_type, validation_result = result.failure
      expect(failure_type).to eq(:invalid)
      expect(validation_result.errors.to_h).to eq(name: ["must be filled"])
    end
  end
end
