# frozen_string_literal: true

begin
  require "active_record"
rescue LoadError
  raise Dry::Operation::MissingDependencyError.new(gem: "activerecord", extension: "ActiveRecord")
end

module Dry
  class Operation
    module Extensions
      # Add ActiveRecord transaction support to operations
      #
      # When this extension is included, you can use a `#transaction` method
      # to wrap the desired steps in an ActiveRecord transaction. If any of the steps
      # returns a `Dry::Monads::Result::Failure`, the transaction will be rolled
      # back and, as usual, the rest of the flow will be skipped.
      #
      # ```ruby
      # class MyOperation < Dry::Operation
      #   include Dry::Operation::Extensions::ActiveRecord
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
      # By default, the `ActiveRecord::Base` class will be used to initiate the transaction.
      # You can change this when including the extension:
      #
      # ```ruby
      # include Dry::Operation::Extensions::ActiveRecord[User]
      # ```
      #
      # Or you can change it at runtime:
      #
      # ```ruby
      # user = transaction(user) do
      #   # ...
      # end
      # ```
      #
      # This is useful when you use multiple databases with ActiveRecord.
      #
      # The extension can be initiated with default options for the transaction.
      # It will be applied to all transactions:
      #
      # ```ruby
      # include Dry::Operation::Extensions::ActiveRecord[requires_new: true]
      # ```
      #
      # You can override these options at runtime:
      #
      # ```ruby
      # transaction(requires_new: false) do
      #   # ...
      # end
      #
      # @see https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html
      # @see https://guides.rubyonrails.org/active_record_multiple_databases.html
      module ActiveRecord
        DEFAULT_CONNECTION = ::ActiveRecord::Base

        # @!method transaction(connection = DEFAULT_CONNECTION, **options, &steps)
        #  Wrap the given steps in an ActiveRecord transaction.
        #
        #  If any of the steps returns a `Dry::Monads::Result::Failure`, the
        #  transaction will be rolled back and `:halt` will be thrown with the
        #  failure as its value.
        #
        #  @param connection [ActiveRecord::Base, #transaction] the class/object to use
        #  @param options [Hash] additional options for the ActiveRecord transaction
        #  @yieldreturn [Object] the result of the block
        #  @see Dry::Operation#steps
        #  @see https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-transaction

        def self.included(klass)
          klass.include(self[])
        end

        # Include the extension providing a custom class/object to initialize the transaction
        # and default options.
        #
        # @param connection [ActiveRecord::Base, #transaction] the class/object to use
        # @param options [Hash] additional options for the ActiveRecord transaction
        def self.[](connection = DEFAULT_CONNECTION, **options)
          Builder.new(connection, **options)
        end

        # @api private
        class Builder < Module
          def initialize(connection, **options)
            super()
            @connection = connection
            @options = options
          end

          def included(klass)
            class_exec(@connection, @options) do |default_connection, options|
              klass.define_method(:transaction) do |connection = default_connection, **opts, &steps|
                connection.transaction(**options.merge(opts)) do
                  intercepting_failure(-> { raise ::ActiveRecord::Rollback }, &steps)
                end
              end
            end
          end
        end
      end
    end
  end
end
