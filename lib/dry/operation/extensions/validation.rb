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

        # The config for how an operation validates its keyword arguments: the contract class, and
        # which keyword arguments are its input.
        #
        # @api private
        Config = Data.define(:contract_class, :for_key, :keys) do
          def initialize(contract_class: nil, for_key: nil, keys: nil)
            raise ArgumentError, "pass either for: or keys:, not both" if for_key && keys

            super
          end
        end

        DEFAULT_CONFIG = Config.new

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
            config = self.class.validation_config

            if (key = config.for_key)
              return Success(kwargs) unless kwargs.key?(key)

              validate(kwargs[key]).fmap { |output| kwargs.merge(key => output) }
            elsif (keys = config.keys)
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
          # @return [Config]
          #
          # @api private
          def validation_config
            @validation_config || DEFAULT_CONFIG
          end

          # @return [Class, nil]
          #
          # @api private
          def contract_class
            validation_config.contract_class
          end

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
          def contract(klass = nil, for: nil, keys: nil, &block)
            # Build the config first, to validate options
            config = Config.new(for_key: binding.local_variable_get(:for), keys:)

            if klass.nil?
              klass = Class.new(Dry::Validation::Contract, &block)
              const_set(CONTRACT_CLASS_NAME, klass)
            end

            @validation_config = config.with(contract_class: klass)
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
          def schema(for: nil, keys: nil, &block)
            raise ArgumentError, "schema requires a block" unless block_given?

            contract(for: binding.local_variable_get(:for), keys:) { schema(&block) }
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
          def params(for: nil, keys: nil, &block)
            raise ArgumentError, "params requires a block" unless block_given?

            contract(for: binding.local_variable_get(:for), keys:) { params(&block) }
          end

          private

          def method_added(method_name)
            return unless @_prepend_manager.registered_methods.include?(method_name)

            _apply_validation(method_name)
            super
          end

          def inherited(subclass)
            super

            if defined?(@validation_config)
              subclass.instance_variable_set(:@validation_config, @validation_config)
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
