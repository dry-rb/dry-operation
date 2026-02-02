# frozen_string_literal: true

begin
  require "rom-sql"
rescue LoadError
  raise Dry::Operation::MissingDependencyError.new(gem: "rom-sql", extension: "ROM")
end

module Dry
  class Operation
    module Extensions
      # Add rom transaction support to operations
      #
      # When this extension is included, you can use a `#transaction` method
      # to wrap the desired steps in a rom transaction. If any of the steps
      # returns a `Dry::Monads::Result::Failure`, the transaction will be rolled
      # back and, as usual, the rest of the flow will be skipped.
      #
      # The extension expects the including class to give access to the rom
      # container via a `#rom` method.
      #
      # ```ruby
      # require "dry/operation/extensions/rom"
      #
      # class MyOperation < Dry::Operation
      #   include Dry::Operation::Extensions::ROM
      #
      #   attr_reader :rom
      #
      #   def initialize(rom:)
      #     @rom = rom
      #   end
      #
      #   def call(input)
      #     attrs = step validate(input)
      #     user = transaction do
      #       new_user = step persist(attrs)
      #       step assign_initial_role(new_user)
      #       new_user
      #     end
      #     step notify(user)
      #     user
      #   end
      #
      #   # ...
      # end
      # ```
      #
      # By default, the `:default` gateway will be used. You can change this
      # when including the extension:
      #
      # ```ruby
      # include Dry::Operation::Extensions::ROM[gateway: :my_gateway]
      # ```
      #
      # Or you can change it at runtime:
      #
      # ```ruby
      # user = transaction(gateway: :my_gateway) do
      #  # ...
      # end
      # ```
      #
      # @see https://rom-rb.org
      module ROM
        DEFAULT_GATEWAY = :default

        # @!method transaction(gateway: DEFAULT_GATEWAY, &steps)
        #  Wrap the given steps in a rom transaction.
        #
        #  If any of the steps returns a `Dry::Monads::Result::Failure`, the
        #  transaction will be rolled back and `:halt` will be thrown with the
        #  failure as its value.
        #
        #  @yieldreturn [Object] the result of the block
        #  @raise [Dry::Operation::ExtensionError] if the including
        #    class doesn't define a `#rom` method.
        #  @see Dry::Operation#steps

        def self.included(klass)
          klass.include(self[])
        end

        # Include the extension providing a custom gateway
        #
        # @param gateway [Symbol] the rom gateway to use
        def self.[](gateway: DEFAULT_GATEWAY)
          Builder.new(gateway: gateway)
        end

        # @api private
        class Builder < Module
          def initialize(gateway:)
            super()
            @gateway = gateway
          end

          def included(_klass)
            default_gateway = @gateway

            define_method(:transaction) do |gateway: default_gateway, **opts, &steps|
              raise Dry::Operation::ExtensionError, <<~MSG unless respond_to?(:rom)
                When using the ROM extension, you need to define a #rom method \
                that returns the ROM container
              MSG

              intercepting_failure do
                result = nil
                rom.gateways[gateway].transaction(**opts) do |t|
                  intercepting_failure(->(failure) {
                                         result = failure
                                         t.rollback!
                                       }) do
                    result = steps.()
                  end
                end
                result
              end
            end
          end
        end
      end
    end
  end
end
