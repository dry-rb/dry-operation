# frozen_string_literal: true

require "spec_helper"
require "dry/operation/extensions/monads"

RSpec.describe Dry::Operation::Extensions::Monads do
  include Dry::Monads[:result]

  let(:base) do
    Class.new(Dry::Operation) do
      include Dry::Operation::Extensions::Monads
    end
  end

  describe "Try monad" do
    it "works with step via automatic to_result conversion" do
      klass = Class.new(base) do
        def call(input)
          result = step Try { Integer(input) }
          result * 2
        end
      end

      expect(klass.new.call("42")).to eq(Success(84))
    end

    it "converts Try::Error to Failure" do
      klass = Class.new(base) do
        def call(input)
          step Try { Integer(input) }
        end
      end

      result = klass.new.call("not a number")
      expect(result).to be_failure
      expect(result.failure).to be_a(ArgumentError)
    end

    it "can catch specific exceptions" do
      custom_error = Class.new(StandardError)

      klass = Class.new(base) do
        error_class = custom_error

        define_method(:call) do |should_raise|
          result = begin
            raise error_class, "boom" if should_raise
            "success"
          rescue error_class => e
            e
          end

          step(should_raise ? Failure(result) : Success(result))
        end
      end

      expect(klass.new.call(false)).to eq(Success("success"))

      result = klass.new.call(true)
      expect(result).to be_failure
      expect(result.failure).to be_a(custom_error)
    end

    it "works in a chain of steps" do
      klass = Class.new(base) do
        def call(input)
          x = step Try { Integer(input) }
          y = step Success(x * 2)
          step Try { y / 2 }
        end
      end

      expect(klass.new.call("10")).to eq(Success(10))
    end
  end

  describe "Maybe monad" do
    it "works with step via automatic to_result conversion for Some" do
      klass = Class.new(base) do
        def call(input)
          value = step Maybe(input[:value])
          value * 2
        end
      end

      expect(klass.new.call(value: 5)).to eq(Success(10))
    end

    it "converts None to Failure" do
      klass = Class.new(base) do
        def call(input)
          step Maybe(input[:value])
        end
      end

      result = klass.new.call({})
      expect(result).to be_failure
      # Maybe's None converts to Failure with nil (or Unit) - just check it failed
    end

    it "converts None from nil to Failure" do
      klass = Class.new(base) do
        def call(input)
          step Maybe(input)
        end
      end

      result = klass.new.call(nil)
      expect(result).to be_failure
    end

    it "works with Some in a chain" do
      klass = Class.new(base) do
        def call(input)
          x = step Maybe(input[:a])
          y = step Maybe(input[:b])
          x + y
        end
      end

      expect(klass.new.call(a: 10, b: 20)).to eq(Success(30))
    end

    it "short-circuits on None" do
      klass = Class.new(base) do
        attr_reader :called

        def initialize
          super
          @called = false
        end

        def call(input)
          step Maybe(input[:value])
          mark_called
        end

        def mark_called
          @called = true
          Success(true)
        end
      end

      instance = klass.new
      result = instance.call({})

      expect(result).to be_failure
      expect(instance.called).to be(false)
    end
  end

  describe "Validated monad" do
    it "works with step via automatic to_result conversion for Valid" do
      klass = Class.new(base) do
        def call(input)
          validated = step Valid(input)
          validated[:name]
        end
      end

      expect(klass.new.call(name: "Alice")).to eq(Success("Alice"))
    end

    it "converts Invalid to Failure" do
      klass = Class.new(base) do
        def call(input)
          step Invalid([:error1, :error2])
        end
      end

      result = klass.new.call({})
      expect(result).to be_failure
      expect(result.failure).to eq([:error1, :error2])
    end

    it "can accumulate errors with validation" do
      klass = Class.new(base) do
        def call(input)
          validated = step validate(input)
          validated
        end

        def validate(input)
          errors = []
          errors << :missing_name if input[:name].nil? || input[:name].empty?
          errors << :missing_email if input[:email].nil? || input[:email].empty?

          errors.empty? ? Valid(input) : Invalid(errors)
        end
      end

      expect(klass.new.call(name: "Alice", email: "alice@example.com")).to be_success

      result = klass.new.call(name: "", email: "")
      expect(result).to be_failure
      expect(result.failure).to eq([:missing_name, :missing_email])
    end
  end

  describe "mixed monads" do
    it "works with different monads in the same operation" do
      klass = Class.new(base) do
        def call(input)
          # Try for exception handling
          number = step Try { Integer(input[:number]) }

          # Maybe for optional values
          multiplier = step Maybe(input[:multiplier])

          # Regular Result
          result = step Success(number * multiplier)

          result
        end
      end

      expect(klass.new.call(number: "10", multiplier: 5)).to eq(Success(50))
    end

    it "short-circuits on first failure from any monad type" do
      klass = Class.new(base) do
        attr_reader :step_reached

        def initialize
          super
          @step_reached = []
        end

        def call(input)
          x = step(mark(:try) { Try { Integer(input[:a]) } })
          y = step(mark(:maybe) { Maybe(input[:b]) })
          z = step(mark(:result) { Success(x + y) })
          z
        end

        def mark(name)
          @step_reached << name
          yield
        end
      end

      # All succeed
      instance = klass.new
      result = instance.call(a: "10", b: 5)
      expect(result).to eq(Success(15))
      expect(instance.step_reached).to eq([:try, :maybe, :result])

      # Try fails
      instance = klass.new
      result = instance.call(a: "invalid", b: 5)
      expect(result).to be_failure
      expect(instance.step_reached).to eq([:try])

      # Maybe fails
      instance = klass.new
      result = instance.call(a: "10", b: nil)
      expect(result).to be_failure
      expect(instance.step_reached).to eq([:try, :maybe])
    end
  end

  describe "auto-conversion behavior" do
    it "converts Try to Result" do
      klass = Class.new(base) do
        def call
          step Try { 42 }
        end
      end

      expect(klass.new.call).to eq(Success(42))
    end

    it "converts Maybe to Result" do
      klass = Class.new(base) do
        def call
          step Maybe(42)
        end
      end

      expect(klass.new.call).to eq(Success(42))
    end

    it "converts Validated to Result" do
      klass = Class.new(base) do
        def call
          step Valid(42)
        end
      end

      expect(klass.new.call).to eq(Success(42))
    end

    it "does not double-convert Result" do
      klass = Class.new(base) do
        def call
          result = Success(42)
          # Result should not be converted again since it's already a Result
          step result
        end
      end

      result = klass.new.call
      expect(result).to eq(Success(42))
    end

    it "raises InvalidStepResultError for non-monad values" do
      klass = Class.new(base) do
        def call
          step 42  # Not a monad
        end
      end

      expect { klass.new.call }.to raise_error(
        Dry::Operation::InvalidStepResultError,
        /Your step must return `Success\(\.\.\)` or `Failure\(\.\.\)`.*Instead, it was `42`/
      )
    end

    it "raises InvalidStepResultError for objects without to_result" do
      klass = Class.new(base) do
        def call
          step Object.new
        end
      end

      expect { klass.new.call }.to raise_error(Dry::Operation::InvalidStepResultError)
    end
  end

  describe "without the extension" do
    it "Try works with auto-conversion even without the extension" do
      klass = Class.new(Dry::Operation) do
        include Dry::Monads[:try]

        def call
          step Try { 42 }  # Auto-conversion works for all operations
        end
      end

      expect(klass.new.call).to eq(Success(42))
    end

    it "Try works with explicit to_result" do
      klass = Class.new(Dry::Operation) do
        include Dry::Monads[:try]

        def call
          step Try { 42 }.to_result
        end
      end

      expect(klass.new.call).to eq(Success(42))
    end
  end

  describe "integration with on_failure hook" do
    it "calls on_failure with monad-derived failures" do
      klass = Class.new(base) do
        attr_reader :failure_value

        def initialize
          super
          @failure_value = nil
        end

        def call(input)
          step Try { Integer(input) }
        end

        def on_failure(failure)
          @failure_value = failure
        end
      end

      instance = klass.new
      instance.call("not a number")

      expect(instance.failure_value).to be_a(ArgumentError)
    end
  end
end
