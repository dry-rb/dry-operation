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
  # method name by inheriting from `Dry::Operation[prepend:
  # :another_method]` or `Dry::Operation[prepend: [:method_one, :method_two]]`
  # for multiple methods.
  #
  # ```ruby
  # class MyOperation < Dry::Operation[prepend: :run]
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
  # You can opt out altogether of this behavior by inheriting from
  # `Dry::Operation[prepend: false]`. If so, you manually need to wrap your flow
  # within the {#steps} method.
  #
  # ```ruby
  # class MyOperation < Dry::Operation[prepend: false]
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
  class Operation
    def self.loader
      @loader ||= Zeitwerk::Loader.new.tap do |loader|
        root = File.expand_path "..", __dir__
        loader.inflector = Zeitwerk::GemInflector.new("#{root}/dry/operation.rb")
        loader.tag = "dry-operation"
        loader.push_dir root
      end
    end
    loader.setup

    # @param prepend [Symbol, Array<Symbol>, false] method(s) to wrap as the
    #   block in {#steps}. `false` for none.
    # @return [Class]
    def self.[](prepend:)
      enable(klass: Class.new, prepend: prepend)
    end

    # @api private
    def self.enable(klass:, prepend:)
      klass.tap do
        klass.include(Mixin)
        Prepender.inherited_hook(klass: klass, methods: Array(prepend))
      end
    end

    # @!parse include Mixin
    enable(klass: self, prepend: :call)
  end
end
