# frozen_string_literal: true

module Dry
  class Operation
    module Extensions
      # Includes additional dry-monads for use in operations
      #
      # This extension provides convenient access to commonly used monads from dry-monads
      # that work seamlessly with {#step} via automatic conversion to Result.
      #
      # The following monads are included:
      # - `Try` - for exception handling
      # - `Maybe` - for handling nil/None/Some cases
      # - `Validated` - for validation with error accumulation
      #
      # Note: The `Do` notation is intentionally not included, as dry-operation's {#step}
      # serves the same purpose.
      #
      # @example
      #   require "dry/operation/extensions/monads"
      #
      #   class MyOperation < Dry::Operation
      #     include Dry::Operation::Extensions::Monads
      #
      #     def call(input)
      #       # Use Try for exception handling
      #       data = step Try { fetch_data(input) }
      #
      #       # Use Maybe for nil handling
      #       value = step Maybe(input[:optional_field])
      #
      #       # Use Validated for validation
      #       attrs = step validate(input)
      #
      #       process(data, value, attrs)
      #     end
      #
      #     def fetch_data(input)
      #       # May raise an exception
      #       HTTP.get("/data/#{input}")
      #     end
      #
      #     def validate(input)
      #       # Returns Validated monad
      #       # ...
      #     end
      #   end
      #
      # @see https://dry-rb.org/gems/dry-monads/
      module Monads
        def self.included(base)
          base.include Dry::Monads[:try, :maybe, :validated]
        end
      end
    end
  end
end
