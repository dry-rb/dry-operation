# frozen_string_literal: true

begin
  require "sequel"
rescue LoadError
  raise Dry::Operation::MissingDependencyError.new(gem: "sequel", extension: "Sequel")
end

module Dry
  class Operation
    module Extensions
      # Add Sequel transaction support to operations
      #
      # When this extension is included, you can use a `#transaction` method
      # to wrap the desired steps in a Sequel transaction. If any of the steps
      # returns a `Dry::Monads::Result::Failure`, the transaction will be rolled
      # back and, as usual, the rest of the flow will be skipped.
      #
      # The extension expects the including class to give access to the Sequel
      # database object via a `#db` method.
      #
      # ```ruby
      # class MyOperation < Dry::Operation
      #   include Dry::Operation::Extensions::Sequel
      #
      #   attr_reader :db
      #
      #   def initialize(db:)
      #     @db = db
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
      # By default, no options are passed to the Sequel transaction. You can
      # change this when including the extension:
      #
      # ```ruby
      # include Dry::Operation::Extensions::Sequel[isolation: :serializable]
      # ```
      #
      # Or you can change it at runtime:
      #
      # ```ruby
      # transaction(isolation: :serializable) do
      #   # ...
      # end
      # ```
      #
      # WARNING: Be aware that the `:savepoint` option is not yet supported.
      #
      # @see http://sequel.jeremyevans.net/rdoc/files/doc/transactions_rdoc.html
      module Sequel
        def self.included(klass)
          klass.include(self[])
        end

        # Include the extension providing default options for the transaction.
        #
        # @param options [Hash] additional options for the Sequel transaction
        def self.[](options = {})
          Builder.new(**options)
        end

        # @api private
        class Builder < Module
          def initialize(**options)
            super()
            @options = options
          end

          def included(klass)
            class_exec(@options) do |default_options|
              klass.define_method(:transaction) do |**opts, &steps|
                raise Dry::Operation::ExtensionError, <<~MSG unless respond_to?(:db)
                  When using the Sequel extension, you need to define a #db method \
                  that returns the Sequel database object
                MSG

                intercepting_failure do
                  result = nil
                  db.transaction(**default_options.merge(opts)) do
                    intercepting_failure(->(failure) {
                      result = failure
                      raise ::Sequel::Rollback
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
end
