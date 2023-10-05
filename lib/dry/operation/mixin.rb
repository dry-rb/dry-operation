# frozen_string_literal: true

module Dry
  class Operation
    module Mixin
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

      # Unwrapps a {Dry::Monads::Result::Success}
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
end
