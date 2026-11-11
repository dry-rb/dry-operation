# frozen_string_literal: true

begin
  require "dry/validation"
rescue LoadError
  raise Dry::Operation::MissingDependencyError.new(gem: "dry-validation", extension: "Validation")
end

module Dry
  class Operation
    module Extensions
      # Adds validation support to operations using Dry Validation.
      #
      # When this extension is included, define your contract on your operation class using
      # `params`, `schema`, or `contract`, or make a `#contract` dependency available from your
      # operation instance. The operation's keyword arguments are validated before its method body
      # runs, and the method receives the contract's output in place of the input it was called with.
      # Positional arguments are never validated, and are always passed through untouched.
      #
      # By default, the keyword arguments are validated as a whole:
      #
      # ```
      # class CreateUser < Dry::Operation
      #   include Dry::Operation::Extensions::Validation
      #
      #   params do
      #     required(:name).filled(:string)
      #   end
      #
      #   def call(name:)
      #     # ...
      #   end
      # end
      #
      # CreateUser.new.call(name: "Alice")
      # ```
      #
      # Use `for:` to validate the value of a single keyword argument, leaving the others untouched:
      #
      # ```
      # class UpdateUser < Dry::Operation
      #   include Dry::Operation::Extensions::Validation
      #
      #   params(for: :attrs) do
      #     required(:name).filled(:string)
      #   end
      #
      #   def call(user, attrs:, notify: false)
      #     # ...
      #   end
      # end
      #
      # UpdateUser.new.call(user, attrs: {name: "Alice", admin: true}, notify: true)
      # # user is passed through untouched
      # # attrs is {name: "Alice"}, with admin filtered out by the contract
      # # notify is passed through untouched
      # ```
      #
      # Use `keys:` to validate a subset of the keyword arguments, leaving the others untouched:
      #
      # ```
      # class AuthorizeCode < Dry::Operation
      #   include Dry::Operation::Extensions::Validation
      #
      #   params(keys: %i[account_id scope]) do
      #     required(:account_id).filled(:string)
      #     optional(:scope).array(:string)
      #   end
      #
      #   def call(code, account_id:, scope: [], notify: false)
      #     # ...
      #   end
      # end
      # ```
      #
      # When a `for:` keyword argument is not given, there is nothing to validate, so the method is
      # called without it, and its own signature decides whether that is allowed.
      #
      # When there is no contract defined, all arguments are forwarded untouched.
      #
      # @see https://hanakai.org/learn/dry/dry-validation
      #
      # @api public
      # @since 1.2.0
      module Validation
        CONTRACT_CLASS_NAME = "Contract"

        def self.included(klass)
          klass.extend(ClassMethods)
          klass.prepend(InstanceMethods)
        end

        # @api public
        # @since 1.2.0
        module InstanceMethods
          include Dry::Monads::Result::Mixin

          private

          # Returns the contract to use for validation.
          #
          # Uses an existing `@contract`, if present, otherwise initializes an instance of the
          # contract defined on the class, and stores it as `@contract`.
          #
          # @return [Dry::Validation::Contract, nil]
          #
          # @api private
          def contract
            return @contract if defined?(@contract)

            @contract = self.class.contract_class&.new
          end

          # Validates the keyword arguments given to an operation method, according to the input
          # configured by the `for:` or `keys:` options given when defining the contract.
          #
          # @param kwargs [Hash] The keyword arguments given to the method
          # @return [Dry::Monads::Result] Success with the keyword arguments to pass to the method,
          #   or Failure with result
          #
          # @api private
          def validate_kwargs(kwargs)
            if (key = self.class.contract_for)
              return Success(kwargs) unless kwargs.key?(key)

              validate(kwargs[key]).fmap { |output| kwargs.merge(key => output) }
            elsif (keys = self.class.contract_keys)
              validate(kwargs.slice(*keys)).fmap { |output| kwargs.except(*keys).merge(output) }
            else
              validate(kwargs)
            end
          end

          # Validates the input using the operation's {#contract}.
          #
          # @param input [Hash] The input to validate
          # @return [Dry::Monads::Result] Success with validated input, or Failure with result
          #
          # @api private
          def validate(input)
            return Success(input) unless contract

            result = contract.call(input)

            if result.success?
              Success(result.to_h)
            else
              Failure[:invalid, result]
            end
          end
        end

        # @api public
        # @since 1.2.0
        module ClassMethods
          # @api private
          attr_reader :contract_class

          # @api private
          attr_reader :contract_for

          # @api private
          attr_reader :contract_keys

          # Defines a validation contract using the full contract DSL.
          #
          # @param klass [Class, nil] A Dry::Validation::Contract subclass to use
          # @param for [Symbol, nil] The keyword argument whose value to validate
          # @param keys [Array<Symbol>, nil] The keyword arguments to validate together
          # @yield Block for defining contract rules
          # @return [void]
          #
          # @api public
          # @since 1.2.0
          def contract(klass = nil, keys: nil, **options, &block)
            _configure_contract_input(keys:, **options)

            if klass.nil?
              klass = Class.new(Dry::Validation::Contract, &block)
              const_set(CONTRACT_CLASS_NAME, klass)
            end

            @contract_class = klass
            _apply_validation
          end

          # Defines a validation contract using the schema DSL only.
          #
          # @param for [Symbol, nil] The keyword argument whose value to validate
          # @param keys [Array<Symbol>, nil] The keyword arguments to validate together
          # @yield Block for defining schema validation rules
          # @return [void]
          #
          # @api public
          # @since 1.2.0
          def schema(keys: nil, **options, &block)
            raise ArgumentError, "schema requires a block" unless block_given?

            _configure_contract_input(keys:, **options)

            klass = Class.new(Dry::Validation::Contract) { schema(&block) }
            const_set(CONTRACT_CLASS_NAME, klass)

            @contract_class = klass
            _apply_validation
          end

          # Defines a validation contract using the params schema DSL only.
          #
          # @param for [Symbol, nil] The keyword argument whose value to validate
          # @param keys [Array<Symbol>, nil] The keyword arguments to validate together
          # @yield Block for defining params validation rules
          # @return [void]
          #
          # @api public
          # @since 1.2.0
          def params(keys: nil, **options, &block)
            raise ArgumentError, "params requires a block" unless block_given?

            _configure_contract_input(keys:, **options)

            klass = Class.new(Dry::Validation::Contract) { params(&block) }
            const_set(CONTRACT_CLASS_NAME, klass)

            @contract_class = klass
            _apply_validation
          end

          private

          # `for` is a reserved word, so it is taken from the options hash rather than declared as a
          # keyword argument.
          def _configure_contract_input(keys:, **options)
            unknown = options.keys - [:for]
            raise ArgumentError, "unknown keyword: #{unknown.map(&:inspect).join(", ")}" if unknown.any?

            key = options[:for]
            raise ArgumentError, "pass either for: or keys:, not both" if key && keys

            @contract_for = key
            @contract_keys = keys
          end

          def method_added(method_name)
            return unless @_prepend_manager.registered_methods.include?(method_name)

            _apply_validation(method_name)
            super
          end

          def inherited(subclass)
            super

            if defined?(@contract_class)
              subclass.instance_variable_set(:@contract_class, @contract_class)
              subclass.instance_variable_set(:@contract_for, @contract_for)
              subclass.instance_variable_set(:@contract_keys, @contract_keys)
            end
          end

          def _apply_validation(*method_names)
            method_names = @_prepend_manager.registered_methods if method_names.empty?
            method_names &= @_prepend_manager.registered_methods

            @_validated_methods ||= []

            method_names.each do |method_name|
              next if @_validated_methods.include?(method_name)

              prepend ValidationStep.new(method_name)
              @_validated_methods << method_name
            end
          end
        end

        # @api private
        class ValidationStep < Module
          def initialize(method_name)
            super()
            @method_name = method_name
            define_validation_method
          end

          def name
            "Dry::Operation::Extensions::Validation::ValidationStep[#{@method_name}]"
          end

          private

          def define_validation_method
            define_method(@method_name) do |*args, **kwargs, &block|
              # Without a contract there's nothing to validate, so the arguments the method was
              # called with are forwarded untouched.
              return super(*args, **kwargs, &block) unless contract

              super(*args, **step(validate_kwargs(kwargs)), &block)
            end
          end
        end
      end
    end
  end
end
