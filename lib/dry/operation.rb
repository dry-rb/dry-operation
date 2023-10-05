# frozen_string_literal: true

require "zeitwerk"
require "dry/monads"

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
  # method with {ClassContext#operate_on}:
  #
  # ```ruby
  # class MyOperation < Dry::Operation
  #   operate_on :run
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
  # You can opt out altogether of this behavior via {ClassContext#skip_prepending}. If so,
  # you manually need to wrap your flow within the {#steps} method.
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
  #     end
  #   end
  #
  #   # ...
  # end
  # ```
  #
  # The behavior configured by {ClassContext#operate_on} and {ClassContext#skip_prepending} is
  # inherited by subclasses.
  class Operation
    def self.loader
      @loader ||= Zeitwerk::Loader.new.tap do |loader|
        root = File.expand_path "..", __dir__
        loader.inflector = Zeitwerk::GemInflector.new("#{root}/dry/operation.rb")
        loader.tag = "dry-operation"
        loader.push_dir root
        loader.ignore(
          "#{root}/dry/operation/errors.rb"
        )
      end
    end
    loader.setup

    extend ClassContext
    include Dry::Monads::Result::Mixin

    # Wraps block's return value in a {Dry::Monads::Result::Success}
    #
    # Catches :halt and returns it
    #
    # @yieldreturn [Object]
    # @return [Dry::Monads::Result::Success]
    # @see #step
    def steps(&block)
      catch(:halt) { Success(block.call) }
    end

    # Unwraps a {Dry::Monads::Result::Success}
    #
    # Throws :halt with a {Dry::Monads::Result::Failure} on failure.
    #
    # @param result [Dry::Monads::Result]
    # @return [Object] wrapped value
    # @see #steps
    def step(result)
      result.value_or { throw :halt, result }
    end
  end
end
