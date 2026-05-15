# frozen_string_literal: true

require "zeitwerk"
require "dry/core/constants"
require "dry/monads"
require "dry/operation/errors"

module Dry
  # DSL for chaining operations that can fail
  #
  # {Dry::Operation} is a thin DSL wrapping dry-monads that allows you to chain
  # operations by focusing on the happy path and short-circuiting on failure.
  #
  # The canonical way of using it is to subclass {Dry::Operation} and define
  # your flow in the `#call` method. Individual operations can be called with
  # {#step}. They need to return either a success or a failure result.
  # Successful results will be automatically unwrapped, while a failure will
  # stop further execution of the method.
  #
  # ```ruby
  # class MyOperation < Dry::Operation
  #   def call(input)
  #     attrs = step validate(input)
  #     user = step persist(attrs)
  #     step notify(user)
  #     user
  #   end
  #
  #   def validate(input)
  #    # Dry::Monads::Result::Success or Dry::Monads::Result::Failure
  #   end
  #
  #   def persist(attrs)
  #    # Dry::Monads::Result::Success or Dry::Monads::Result::Failure
  #   end
  #
  #   def notify(user)
  #    # Dry::Monads::Result::Success or Dry::Monads::Result::Failure
  #   end
  # end
  #
  # include Dry::Monads[:result]
  #
  # case MyOperation.new.call(input)
  # in Success(user)
  #   puts "User #{user.name} created"
  # in Failure[:invalid_input, validation_errors]
  #   puts "Invalid input: #{validation_errors}"
  # in Failure(:database_error)
  #   puts "Database error"
  # in Failure(:email_error)
  #   puts "Email error"
  # end
  # ```
  #
  # Under the hood, the `#call` method is decorated to allow skipping the rest
  # of its execution when a failure is encountered. You can choose to use another
  # method with {ClassContext#operate_on} (which also accepts a list of methods):
  #
  # ```ruby
  # class MyOperation < Dry::Operation
  #   operate_on :run # or operate_on :run, :call
  #
  #   def run(input)
  #     attrs = step validate(input)
  #     user = step persist(attrs)
  #     step notify(user)
  #     user
  #   end
  #
  #   # ...
  # end
  # ```
  #
  # As you can see, the aforementioned behavior allows you to write your flow
  # in a linear fashion. Failures are mostly handled locally by each individual
  # operation. However, you can also define a global failure handler by defining
  # an `#on_failure` method. It will always be called with the wrapped failure
  # value as its first argument, and may optionally accept either a positional
  # second argument (the prepended method name) or `step_name:` and/or
  # `method_name:` keyword arguments:
  #
  # ```ruby
  # class MyOperation < Dry::Operation
  #   def call(input)
  #     attrs = step :validate, validate(input)
  #     user = step :persist, persist(attrs)
  #     step :notify, notify(user)
  #     user
  #   end
  #
  #   def on_failure(failure_value, step_name:)
  #     case step_name
  #     when :validate then log_validation_failure(failure_value)
  #     when :persist then log_persistence_failure(failure_value)
  #     when :notify then log_notification_failure(failure_value)
  #     end
  #   end
  # end
  # ```
  #
  # Naming steps is optional. When {#step} is called with just a result,
  # `step_name:` will be `nil`. The `method_name:` kwarg always reflects the
  # prepended method name (`:call` by default).
  #
  # You can opt out altogether of this behavior via {ClassContext#skip_prepending}. If so,
  # you manually need to wrap your flow within the {#steps} method.
  # `#on_failure` is still dispatched by `#steps` itself, so it works the same
  # as in the prepended case:
  #
  # ```ruby
  # class MyOperation < Dry::Operation
  #   skip_prepending
  #
  #   def call(input)
  #     steps do
  #       attrs = step :validate, validate(input)
  #       user  = step :persist, persist(attrs)
  #       step :notify, notify(user)
  #       user
  #     end
  #   end
  #
  #   def on_failure(failure, step_name:)
  #     log_failure(failure, step_name)
  #   end
  # end
  # ```
  #
  # The behavior configured by {ClassContext#operate_on} and {ClassContext#skip_prepending} is
  # inherited by subclasses.
  #
  # Some extensions are available under the `Dry::Operation::Extensions`
  # namespace, providing additional functionality that can be included in your
  # operation classes.
  class Operation
    def self.loader
      @loader ||= Zeitwerk::Loader.new.tap do |loader|
        root = File.expand_path "..", __dir__
        loader.inflector = Zeitwerk::GemInflector.new("#{root}/dry/operation.rb")
        loader.tag = "dry-operation"
        loader.push_dir root
        loader.ignore(
          "#{root}/dry/operation/errors.rb",
          "#{root}/dry/operation/extensions/*.rb"
        )
        loader.inflector.inflect("rom" => "ROM")
      end
    end
    loader.setup

    # @api private
    FAILURE_TAG = :halt

    # @api private
    Undefined = Dry::Core::Constants::Undefined

    # Internal throw payload pairing a failure with the name of the step that
    # produced it. Used so the step name can flow back to `#on_failure`.
    #
    # @api private
    StepFailure = Data.define(:failure, :step_name)

    extend ClassContext
    include Dry::Monads::Result::Mixin

    # Wraps block's return value in a {Dry::Monads::Result::Success}
    #
    # Catches `:halt`, unwraps any step name carried by the throw, and
    # dispatches the failure (if any) to `#on_failure`.
    #
    # The prepender passes its `__method__` as `method_name:` so it flows to
    # `#on_failure`'s `method_name:` kwarg. Manual callers (e.g. with
    # {ClassContext#skip_prepending}) can pass it themselves; otherwise the
    # `method_name:` kwarg arrives as `nil`.
    #
    # @param method_name [Symbol, nil] surfaced to `#on_failure` via `method_name:` on failure
    # @yieldreturn [Object]
    # @return [Dry::Monads::Result::Success, Object] the wrapped block result, or
    #   the unwrapped failure / direct-throw value
    # @see #step
    def steps(method_name: nil, &block)
      output = catch(FAILURE_TAG) { Success(block.call) }

      result, step_name =
        if output.is_a?(StepFailure)
          [output.failure, output.step_name]
        else
          [output, nil]
        end

      ClassContext::FailureHookDispatcher.call(
        self,
        method_name: method_name,
        step_name: step_name,
        result: result
      )

      result
    end

    # Unwraps a {Dry::Monads::Result::Success}
    #
    # Throws `:halt` with a {Dry::Monads::Result::Failure} on failure.
    #
    # If the given result responds to `#to_result`, this will be called before processing.
    #
    # Optionally accepts a step name as the first argument. When given, the name is
    # forwarded to `#on_failure` via the `step_name:` kwarg if the step fails.
    #
    # ```ruby
    # def call(input)
    #   attrs = step :validate, validate(input)
    #   user  = step :persist, persist(attrs)
    #   step :notify, notify(user)
    #   user
    # end
    # ```
    #
    # @overload step(result)
    #   @param result [Dry::Monads::Result, #to_result]
    # @overload step(name, result)
    #   @param name [Symbol] identifier surfaced to `#on_failure` via `step_name:` on failure
    #   @param result [Dry::Monads::Result, #to_result]
    # @return [Object] wrapped value
    # @see #steps
    def step(name_or_result, result = Undefined)
      if Undefined.equal?(result)
        step_name = nil
        result = name_or_result
      else
        step_name = name_or_result
      end

      raise InvalidStepResultError.new(result: result) unless result.respond_to?(:to_result)

      result = result.to_result
      result.value_or { throw_failure(result, step_name:) }
    end

    # Invokes a callable in case of block's failure
    #
    # This method is useful when you want to perform some side-effect when a
    # failure is encountered. It's meant to be used within the {#steps} block
    # commonly wrapping a sub-set of {#step} calls.
    #
    # @param handler [#call] a callable that will be called with the encountered failure.
    #   By default, it throws `FAILURE_TAG` with the failure.
    # @yieldreturn [Object]
    # @return [Object] the block's return value when it's not a failure or the handler's
    #   return value when the block returns a failure
    def intercepting_failure(handler = method(:throw_failure), &block)
      output = catching_failure(&block)

      case output
      when Failure
        handler.(output)
      else
        output
      end
    end

    # Throws `:halt` with a failure
    #
    # @param failure [Dry::Monads::Result::Failure]
    # @param step_name [Symbol, nil] surfaced to `#on_failure` if set
    def throw_failure(failure, step_name: nil)
      throw FAILURE_TAG, StepFailure.new(failure, step_name)
    end

    private

    def catching_failure(&block)
      output = catch(FAILURE_TAG, &block)
      output.is_a?(StepFailure) ? output.failure : output
    end
  end
end
