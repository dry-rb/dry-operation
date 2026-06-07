# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Operations" do
  include Dry::Monads[:result]

  it "chains successful operations and returns wrapping in a Success" do
    klass = Class.new(Dry::Operation) do
      def add_one_then_two(x)
        steps do
          y = step add_one(x)
          step add_two(y)
        end
      end

      def add_one(x) = Success(x + 1)
      def add_two(x) = Success(x + 2)
    end

    expect(
      klass.new.add_one_then_two(1)
    ).to eq(Success(4))
  end

  it "short-circuits on Failure and returns it" do
    klass = Class.new(Dry::Operation) do
      def divide_by_zero_then_add_one(x)
        steps do
          y = step divide_by_zero(x)
          step inc(y)
        end
      end

      def divide_by_zero(_x) = Failure(:not_possible)
      def add_one(x) = Success(x + 1)
    end

    expect(
      klass.new.divide_by_zero_then_add_one(1)
    ).to eq(Failure(:not_possible))
  end

  it "automatically prepends #steps around #call" do
    klass = Class.new(Dry::Operation) do
      def call(x)
        step add_one(x)
      end

      def add_one(x) = Success(x + 1)
    end

    expect(
      klass.new.(1)
    ).to eq(Success(2))
  end

  it "keeps prepending down the inheritance tree" do
    klass = Class.new(Dry::Operation)
    qlass = Class.new(klass) do
      def call(x)
        step add_one(x)
      end

      def add_one(x) = Success(x + 1)
    end

    expect(
      qlass.new.(1)
    ).to eq(Success(2))
  end

  context "#on_failure" do
    it "is called when prepending if a failure is returned" do
      klass = Class.new(Dry::Operation) do
        attr_reader :failure

        def initialize
          super
          @failure = nil
        end

        def call(x)
          step divide_by_zero(x)
        end

        def divide_by_zero(_x) = Failure(:not_possible)

        def on_failure(failure)
          @failure = failure
        end
      end
      instance = klass.new

      instance.(1)

      expect(
        instance.failure
      ).to be(:not_possible)
    end

    it "isn't called if a success is returned" do
      klass = Class.new(Dry::Operation) do
        attr_reader :failure

        def initialize
          super
          @failure = nil
        end

        def call(x)
          step add_one(x)
        end

        def add_one(x) = Success(x + 1)

        def on_failure(failure)
          @failure = failure
        end
      end
      instance = klass.new

      instance.(1)

      expect(
        instance.failure
      ).to be(nil)
    end

    it "is given the prepended method name when it accepts a second argument" do
      klass = Class.new(Dry::Operation) do
        attr_reader :method_name

        def initialize
          super
          @method_name = nil
        end

        def call(x)
          step divide_by_zero(x)
        end

        def divide_by_zero(_x) = Failure(:not_possible)

        def on_failure(_failure, method_name)
          @method_name = method_name
        end
      end
      instance = klass.new

      instance.(1)

      expect(
        instance.method_name
      ).to be(:call)
    end

    it "is given the step name via the step_name: kwarg" do
      klass = Class.new(Dry::Operation) do
        attr_reader :received

        def initialize
          super
          @received = nil
        end

        def call(x)
          step :validate, validate(x)
          step :persist, persist(x)
        end

        def validate(_x) = Success(:ok)
        def persist(_x) = Failure(:db_error)

        def on_failure(_failure, step_name:)
          @received = step_name
        end
      end
      instance = klass.new

      instance.(1)

      expect(
        instance.received
      ).to be(:persist)
    end

    it "passes nil for step_name: when an unnamed step fails" do
      klass = Class.new(Dry::Operation) do
        attr_reader :received

        def initialize
          super
          @received = nil
        end

        def call(x)
          step persist(x)
        end

        def persist(_x) = Failure(:db_error)

        def on_failure(_failure, step_name:)
          @received = step_name
        end
      end
      instance = klass.new

      instance.(1)

      expect(
        instance.received
      ).to be_nil
    end

    it "is given the prepended method name via the method_name: kwarg" do
      klass = Class.new(Dry::Operation) do
        attr_reader :received

        def initialize
          super
          @received = nil
        end

        def call(x)
          step :persist, persist(x)
        end

        def persist(_x) = Failure(:db_error)

        def on_failure(_failure, method_name:)
          @received = method_name
        end
      end
      instance = klass.new

      instance.(1)

      expect(
        instance.received
      ).to be(:call)
    end

    it "is given both names when both kwargs are accepted" do
      klass = Class.new(Dry::Operation) do
        attr_reader :received

        def initialize
          super
          @received = nil
        end

        def call(x)
          step :persist, persist(x)
        end

        def persist(_x) = Failure(:db_error)

        def on_failure(_failure, step_name:, method_name:)
          @received = {step_name: step_name, method_name: method_name}
        end
      end
      instance = klass.new

      instance.(1)

      expect(
        instance.received
      ).to eq(step_name: :persist, method_name: :call)
    end

    it "raises a meaningful error when its signature is not supported" do
      klass = Class.new(Dry::Operation) do
        def call(x)
          step divide_by_zero(x)
        end

        def divide_by_zero(_x) = Failure(:not_possible)

        def on_failure(_failure, _method_name, _unknown); end
      end

      expect { klass.new.(1) }.to raise_error(Dry::Operation::FailureHookArityError, /arity is 3/)
    end

    it "raises an error when arity-2 positional is mixed with kwargs" do
      klass = Class.new(Dry::Operation) do
        def call(x)
          step divide_by_zero(x)
        end

        def divide_by_zero(_x) = Failure(:not_possible)

        def on_failure(_failure, _name, step_name:); end
      end

      expect { klass.new.(1) }.to raise_error(Dry::Operation::FailureHookArityError)
    end

    it "raises an error for unrecognised kwargs" do
      klass = Class.new(Dry::Operation) do
        def call(x)
          step divide_by_zero(x)
        end

        def divide_by_zero(_x) = Failure(:not_possible)

        def on_failure(_failure, what:); end
      end

      expect { klass.new.(1) }.to raise_error(Dry::Operation::FailureHookArityError)
    end

    it "can be defined in a parent class" do
      klass = Class.new(Dry::Operation) do
        attr_reader :failure

        def initialize
          super
          @failure = nil
        end

        def on_failure(failure)
          @failure = failure
        end
      end
      qlass = Class.new(klass) do
        def call(x)
          step divide_by_zero(x)
        end

        def divide_by_zero(_x) = Failure(:not_possible)
      end
      instance = qlass.new

      instance.(1)

      expect(
        instance.failure
      ).to be(:not_possible)
    end

    it "can be a private method" do
      klass = Class.new(Dry::Operation) do
        attr_reader :failure

        def initialize
          super
          @failure = nil
        end

        def call(x)
          step divide_by_zero(x)
        end

        def divide_by_zero(_x) = Failure(:not_possible)

        private

        def on_failure(failure)
          @failure = failure
        end
      end
      instance = klass.new

      instance.(1)

      expect(
        instance.failure
      ).to be(:not_possible)
    end
  end

  context ".operate_on" do
    it "allows prepending around a method other than #call" do
      klass = Class.new(Dry::Operation) do
        operate_on :run

        def run(x)
          step add_one(x)
        end

        def add_one(x) = Success(x + 1)
      end

      expect(
        klass.new.run(1)
      ).to eq(Success(2))
    end

    it "keeps prepending down the inheritance tree" do
      klass = Class.new(Dry::Operation) do
        operate_on :run
      end
      qlass = Class.new(klass) do
        def run(x)
          step add_one(x)
        end

        def add_one(x) = Success(x + 1)
      end

      expect(
        qlass.new.run(1)
      ).to eq(Success(2))
    end

    it "stops prepending #call when a different method is passed" do
      klass = Class.new(Dry::Operation) do
        operate_on :run

        def call(x)
          step add_one(x)
        end

        def add_one(x) = Success(x + 1)
      end

      expect(
        klass.new.(1)
      ).to eq(2)
    end

    it "allows prepending around several methods by passing multiple arguments" do
      klass = Class.new(Dry::Operation) do
        operate_on :run, :apply

        def run(x)
          step add_one(x)
        end

        def apply(x)
          step add_one(x)
        end

        def add_one(x) = Success(x + 1)
      end

      expect(
        [klass.new.apply(1), klass.new.run(1)]
      ).to eq([Success(2), Success(2)])
    end

    it "raises an error when called after any of the given methods has already been defined in self" do
      expect {
        Class.new(Dry::Operation) do
          def run; end
          operate_on :run
        end
      }.to raise_error(Dry::Operation::MethodsToPrependAlreadyDefinedError)
    end

    it "doesn't raise an error when called after any of the given method has been defined on a parent class" do
      klass = Class.new(Dry::Operation) do
        def run; end
      end

      expect {
        Class.new(klass) do
          operate_on :run
        end
      }.not_to raise_error
    end

    it "raises an error when called after prepending a method to self" do
      expect {
        Class.new(Dry::Operation) do
          def call; end
          operate_on :run
        end
      }.to raise_error(Dry::Operation::PrependConfigurationError)
    end

    it "doesn't raise an error when called after prepending a method to a parent class" do
      klass = Class.new(Dry::Operation) do
        def call; end
      end

      expect {
        Class.new(klass) do
          operate_on :run
        end
      }.not_to raise_error
    end

    it "doesn't leak from subclasses to other classes in the inheritance tree" do
      klass = Class.new(Dry::Operation) do
        def add_one(x) = Success(x + 1)
      end
      Class.new(klass) do
        operate_on :run
      end

      klass.define_method(:run) do |x|
        step add_one(x)
      end

      expect(
        klass.new.run(1)
      ).to eq(2)
    end
  end

  context ".skip_prepending" do
    it "prevents prepending around any method" do
      klass = Class.new(Dry::Operation) do
        skip_prepending

        def call(x)
          step add_one(x)
        end

        def add_one(x) = Success(x + 1)
      end

      expect(
        klass.new.(1)
      ).to eq(2)
    end

    it "prevents prepending down the inheritance tree" do
      klass = Class.new(Dry::Operation) do
        skip_prepending
      end
      qlass = Class.new(klass) do
        def call(x)
          step add_one(x)
        end

        def add_one(x) = Success(x + 1)
      end

      expect(
        qlass.new.(1)
      ).to eq(2)
    end

    it "raises an error when called after a prepended method has already been defined in self" do
      expect {
        Class.new(Dry::Operation) do
          def call; end
          skip_prepending
        end
      }.to raise_error(Dry::Operation::PrependConfigurationError)
    end

    it "doesn't raise an error when called after a prepended method has been defined on a parent class" do
      klass = Class.new(Dry::Operation) do
        def call; end
      end

      expect {
        Class.new(klass) do
          skip_prepending
        end
      }.not_to raise_error
    end

    it "doesn't leak from subclasses to other classes in the inheritance tree" do
      klass = Class.new(Dry::Operation) do
        def add_one(x) = Success(x + 1)
      end
      Class.new(klass) do
        skip_prepending
      end

      klass.define_method(:call) do |x|
        step add_one(x)
      end

      expect(
        klass.new.(1)
      ).to eq(Success(2))
    end

    it "still dispatches to #on_failure from inside a manual #steps block" do
      received = nil

      klass = Class.new(Dry::Operation) do
        skip_prepending

        def call(x)
          steps do
            step :persist, persist(x)
          end
        end

        def persist(_x) = Failure(:db_error)

        define_method(:on_failure) do |_failure, step_name:|
          received = step_name
        end
      end

      klass.new.(1)

      expect(received).to be(:persist)
    end
  end
end
