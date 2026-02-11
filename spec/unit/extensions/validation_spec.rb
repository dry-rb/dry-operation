# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::Validation do
  include Dry::Monads[:result]

  describe ".contract" do
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

      expect(klass.contract_class).to eq(contract_class)
    end
  end

  describe ".schema" do
    it "creates a Contract class with schema validation" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        schema do
          required(:name).filled(:string)
        end
      end

      expect(klass.contract_class).to be_a(Class)
      expect(klass.contract_class.superclass).to eq(Dry::Validation::Contract)
    end

    it "requires a block" do
      expect {
        Class.new(Dry::Operation) do
          include Dry::Operation::Extensions::Validation

          schema
        end
      }.to raise_error(ArgumentError, "schema requires a block")
    end
  end

  describe ".params" do
    it "creates a Contract class with params validation" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end
      end

      expect(klass.contract_class).to be_a(Class)
      expect(klass.contract_class.superclass).to eq(Dry::Validation::Contract)
    end

    it "requires a block" do
      expect {
        Class.new(Dry::Operation) do
          include Dry::Operation::Extensions::Validation

          params
        end
      }.to raise_error(ArgumentError, "params requires a block")
    end
  end

  describe "#validate" do
    it "returns Success with input when no contract class is defined" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation
      end

      instance = klass.new
      result = instance.send(:validate, name: "John")

      expect(result).to eq(Success(name: "John"))
    end
  end

  describe "ValidationStep ancestors" do
    it "includes named ValidationStep modules in ancestors" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        params do
          required(:name).filled(:string)
        end

        def call(input)
          input
        end
      end

      ancestor_names = klass.ancestors.map(&:name)
      expect(ancestor_names).to include("Dry::Operation::Extensions::Validation::ValidationStep[call]")
    end

    it "includes ValidationStep for custom methods via operate_on" do
      klass = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Validation

        operate_on :process, :transform

        params do
          required(:value).filled(:string)
        end

        def process(input)
          input
        end

        def transform(input)
          input
        end
      end

      ancestor_names = klass.ancestors.map(&:name)
      expect(ancestor_names).to include("Dry::Operation::Extensions::Validation::ValidationStep[process]")
      expect(ancestor_names).to include("Dry::Operation::Extensions::Validation::ValidationStep[transform]")
    end
  end
end
