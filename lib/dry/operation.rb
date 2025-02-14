# frozen_string_literal: true

require "zeitwerk"
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
  # an `#on_failure` method. It will be called with the wrapped failure value
  # and, in the case of accepting a second argument, the name of the method that
  # defined the flow:
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
  #   def on_failure(user) # or def on_failure(failure_value, method_name)
  #     log_failure(user)
  #   end
  # end
  # ```
  #
  # You can opt out altogether of this behavior via {ClassContext#skip_prepending}. If so,
  # you manually need to wrap your flow within the {#steps} method and manually
  # handle global failures.
  #
  # ```ruby
  # class MyOperation < Dry::Operation
  #   skip_prepending
  #
  #   def call(input)
  #     steps do
  #       attrs = step validate(input)
  #       user = step persist(attrs)
  #       step notify(user)
  #       user
  #     end.tap do |result|
  #       log_failure(result.failure) if result.failure?
  #     end
  #   end
  #
  #   # ...
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

    FAILURE_TAG = :halt
    private_constant :FAILURE_TAG

    extend ClassContext
    include Dry::Monads::Result::Mixin

    # Wraps block's return value in a {Dry::Monads::Result::Success}
    #
    # Catches `:halt` and returns it
    #
    # @yieldreturn [Object]
    # @return [Dry::Monads::Result::Success]
    # @see #step
    def steps(&block)
      catching_failure { Success(block.call) }
    end

    # Unwraps a {Dry::Monads::Result::Success}
    #
    # Throws `:halt` with a {Dry::Monads::Result::Failure} on failure.
    #
    # @param result [Dry::Monads::Result]
    # @return [Object] wrapped value
    # @see #steps
    def step(result)
      if result.is_a?(Dry::Monads::Result)
        result.value_or { throw_failure(result) }
      else
        raise InvalidStepResultError.new(result: result)
      end
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
    def throw_failure(failure)
      throw FAILURE_TAG, failure
    end

    private

    def catching_failure(&block)
      catch(FAILURE_TAG, &block)
    end
  end
end
