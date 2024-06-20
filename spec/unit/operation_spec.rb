# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation do
  include Dry::Monads[:result]

  describe "#steps" do
    it "wraps block's return value in a Success" do
      klass = Class.new(described_class) do
        def foo(value)
          steps { value }
        end
      end

      result = klass.new.foo(:foo)

      expect(result).to eq(Success(:foo))
    end

    it "catches :halt and returns it" do
      klass = Class.new(described_class) do
        def foo(value)
          steps { throw :halt, value }
        end
      end

      result = klass.new.foo(:foo)

      expect(result).to be(:foo)
    end
  end

  describe "#step" do
    it "returns wrapped value when given a success" do
      expect(
        described_class.new.step(Success(:foo))
      ).to be(:foo)
    end

    # Make sure we don't use pattern matching to extract the value, as that
    # would be a problem with a value that is an array. See
    # https://https://github.com/dry-rb/dry-monads/issues/173
    it "is able to extract an array from a success result" do
      expect(
        described_class.new.step(Success([:foo]))
      ).to eq([:foo])
    end

    it "throws :halt with the result when given a failure" do
      failure = Failure(:foo)

      expect {
        described_class.new.step(failure)
      }.to throw_symbol(:halt, failure)
    end

    it "raises helpful error when returning `nil` to step" do
      expect {
        described_class.new.step(nil)
      }.to raise_error(Dry::Operation::InvalidStepResultError)
        .with_message(
          <<~MSG
            Your step must return `Success(..)` or `Failure(..)`, \
            from `Dry::Monads::Result`. Instead, it was `nil`.
          MSG
        )
    end

    it "raises helpful error when returning an integer to step" do
      expect {
        described_class.new.step(123)
      }.to raise_error(Dry::Operation::InvalidStepResultError)
        .with_message(
          <<~MSG
            Your step must return `Success(..)` or `Failure(..)`, \
            from `Dry::Monads::Result`. Instead, it was `123`.
          MSG
        )
    end
  end

  describe "#intercepting_failure" do
    it "forwards the block's output when it's not a failure" do
      expect(
        described_class.new.intercepting_failure(-> {}) { :foo }
      ).to be(:foo)
    end

    it "doesn't call the handler when the block doesn't return a failure" do
      called = false

      catch(:halt) {
        described_class.new.intercepting_failure(-> { called = true }) { :foo }
      }

      expect(called).to be(false)
    end

    it "throws :halt with the result when the block returns a failure" do
      expect {
        described_class.new.intercepting_failure(-> {}) { Failure(:foo) }
      }.to throw_symbol(:halt, Failure(:foo))
    end

    it "calls the handler when the block returns a failure" do
      called = false

      catch(:halt) {
        described_class.new.intercepting_failure(-> { called = true }) { Failure(:foo) }
      }

      expect(called).to be(true)
    end
  end
end
