# frozen_string_literal: true

require "zeitwerk"
require "dry/monads"

module Dry
  # DSL for chaining operations that can fail
  #
  # {Dry::Operation} is a thin DSL wrapping dry-monads that allows you to chain
  # operations by focusing on the happy path and short-circuiting on failure.
  #
  # The entry-point for defining your operations flow is {#steps}. It accepts a
  # block where you can call individual operations through {#step}. Operations
  # need to return either a success or a failure result. Successful results will
  # be automatically unwrapped, while a failure will stop further execution of
  # the block.
  #
  # @example
  #  class MyOperation < Dry::Operation
  #    def call(input)
  #      steps do
  #        attrs = step validate(input)
  #        user = step persist(attrs)
  #        step notify(user)
  #        user
  #      end
  #    end
  #
  #    def validate(input)
  #     # Dry::Monads::Result::Success or Dry::Monads::Result::Failure
  #    end
  #
  #    def persist(attrs)
  #     # Dry::Monads::Result::Success or Dry::Monads::Result::Failure
  #    end
  #
  #    def notify(user)
  #     # Dry::Monads::Result::Success or Dry::Monads::Result::Failure
  #    end
  #  end
  #
  #  include Dry::Monads[:result]
  #
  #  case MyOperation.new.call(input)
  #  in Success(user)
  #    puts "User #{user.name} created"
  #  in Failure[:invalid_input, validation_errors]
  #    puts "Invalid input: #{validation_errors}"
  #  in Failure(:database_error)
  #    puts "Database error"
  #  in Failure(:email_error)
  #    puts "Email error"
  #  end
  class Operation
    include Dry::Monads::Result::Mixin

    def self.loader
      @loader ||= Zeitwerk::Loader.new.tap do |loader|
        root = File.expand_path "..", __dir__
        loader.inflector = Zeitwerk::GemInflector.new("#{root}/dry/operation.rb")
        loader.tag = "dry-operation"
        loader.push_dir root
      end
    end
    loader.setup

    # Wraps block's return value in a {Success}
    #
    # Catches :halt and returns it
    #
    # @yieldreturn [Object]
    # @return [Dry::Monads::Result::Success]
    # @see #step
    def steps(&block)
      catch(:halt) { Success(block.call) }
    end

    # Unwrapps a {Success} or throws :halt with a {Failure}
    #
    # @param result [Dry::Monads::Result]
    # @return [Object] wrapped value
    # @see #steps
    def step(result)
      result.value_or { throw :halt, result }
    end
  end
end
