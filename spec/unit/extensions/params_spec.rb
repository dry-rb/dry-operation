# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::Params do
  include Dry::Monads[:result]

  describe ".params" do
    it "creates an anonymous Params class with validation" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

        params do
          required(:name).filled(:string)
        end
      end

      expect(klass._params_class).to be_a(Class)
      expect(klass._params_class.superclass).to eq(Dry::Operation::Extensions::Params::Params)
      expect(klass._params_class._validator).to be_a(Dry::Validation::Contract)
    end

    it "accepts a Params class" do
      params_class = Class.new(Dry::Operation::Extensions::Params::Params) do
        params do
          required(:name).filled(:string)
        end
      end

      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

        params params_class
      end

      expect(klass._params_class).to eq(params_class)
    end

    it "allows params class to be inherited by subclasses" do
      parent = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

        params do
          required(:name).filled(:string)
        end
      end

      child = Class.new(parent)

      expect(child._params_class).to eq(parent._params_class)
    end

    it "allows subclass to override parent params class" do
      parent = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

        params do
          required(:name).filled(:string)
        end
      end

      child = Class.new(parent) do
        params do
          required(:email).filled(:string)
        end
      end

      expect(child._params_class).not_to eq(parent._params_class)
    end
  end

  describe ".contract" do
    it "creates an anonymous Params class with contract validation" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

        contract do
          params do
            required(:name).filled(:string)
          end

          rule(:name) do
            key.failure("must be uppercase") unless value.upcase == value
          end
        end
      end

      expect(klass._params_class).to be_a(Class)
      expect(klass._params_class._validator).to be_a(Dry::Validation::Contract)
    end

    it "accepts a Params class" do
      params_class = Class.new(Dry::Operation::Extensions::Params::Params) do
        contract do
          params do
            required(:name).filled(:string)
          end
        end
      end

      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

        contract params_class
      end

      expect(klass._params_class).to eq(params_class)
    end
  end

  describe "#validate_params" do
    it "returns Success with input when no params class is defined" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params
      end

      instance = klass.new
      result = instance.validate_params(name: "John")

      expect(result).to eq(Success(name: "John"))
    end

    it "returns Success with validated params when validation passes" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

        params do
          required(:name).filled(:string)
        end
      end

      instance = klass.new
      result = instance.validate_params(name: "John")

      expect(result).to eq(Success(name: "John"))
    end

    it "returns Failure with errors when validation fails" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

        params do
          required(:name).filled(:string)
        end
      end

      instance = klass.new
      result = instance.validate_params(name: "")

      expect(result).to be_a(Dry::Monads::Failure)
      expect(result.failure).to eq([:invalid_params, {name: ["must be filled"]}])
    end

    it "coerces values according to schema" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

        params do
          required(:age).value(:integer)
        end
      end

      instance = klass.new
      result = instance.validate_params(age: "25")

      expect(result).to eq(Success(age: 25))
    end

    it "validates contract rules" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

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

      result = instance.validate_params(name: "JOHN")
      expect(result).to eq(Success(name: "JOHN"))

      result = instance.validate_params(name: "john")
      expect(result).to be_a(Dry::Monads::Failure)
      expect(result.failure).to eq([:invalid_params, {name: ["must be uppercase"]}])
    end
  end

  describe "method wrapping" do
    it "validates params before calling the method" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

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
        include Dry::Operation::Extensions::Params

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
      expect(result.failure).to eq([:invalid_params, {name: ["must be filled"]}])
      expect(executed).to be(false)
    end

    it "works with custom methods specified via operate_on" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

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

    it "validates custom methods when params is defined before the method" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Params

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
      expect(result.failure).to eq([:invalid_params, {name: ["must be filled"]}])
    end
  end
end
