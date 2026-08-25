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
      # operation instance. The operation's input is validated before its method body runs, and the
      # method receives the contract's output in place of the input it was called with.
      #
      # The input is the last positional argument (when positional args are present), or the keyword
      # arguments in full. Both of these validate `{name: "Alice"}`:
      #
      # ```
      # operation.call(name: "Alice")
      # operation.call({name: "Alice"})
      # ```
      #
      # When the input is given as a positional argument, any earlier positional arguments and any
      # keyword arguments are considered the operation's own. They never pass through the validation
      # contract, and are never set by the contract's output. Use these for arguments that control
      # the operation's own behavior alongside its validated input.
      #
      # ```
      # class UpdateUser < Dry::Operation
      #   include Dry::Operation::Extensions::Validation
      #
      #   params do
      #     required(:name).filled(:string)
      #   end
      #
      #   def call(id, attrs, notify: false)
      #     step persist(id, attrs)
      #   end
      # end
      #
      # update_user = UpdateUser.new
      # update_user.call(123, {name: "Alice", admin: true}, notify: true)
      # # id is 123 - not passed through the contract
      # # attrs is {name: "Alice"} - admin filtered out by the contract
      # # notify is true - not passed through the contract
      # ```
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

          # Defines a validation contract using the full contract DSL.
          #
          # @param klass [Class, nil] A Dry::Validation::Contract subclass to use
          # @yield Block for defining contract rules
          # @return [void]
          #
          # @api public
          # @since 1.2.0
          def contract(klass = nil, &block)
            if klass.nil?
              klass = Class.new(Dry::Validation::Contract, &block)
              const_set(CONTRACT_CLASS_NAME, klass)
            end

            @contract_class = klass
            _apply_validation
          end

          # Defines a validation contract using the schema DSL only.
          #
          # @yield Block for defining schema validation rules
          # @return [void]
          def schema(&block)
            raise ArgumentError, "schema requires a block" unless block_given?

            klass = Class.new(Dry::Validation::Contract) { schema(&block) }
            const_set(CONTRACT_CLASS_NAME, klass)

            @contract_class = klass
            _apply_validation
          end

          # Defines a validation contract using the params schema DSL only.
          #
          # @yield Block for defining params validation rules
          # @return [void]
          #
          # @api public
          # @since 1.2.0
          def params(&block)
            raise ArgumentError, "params requires a block" unless block_given?

            klass = Class.new(Dry::Validation::Contract) { params(&block) }
            const_set(CONTRACT_CLASS_NAME, klass)

            @contract_class = klass
            _apply_validation
          end

          private

          def method_added(method_name)
            return unless @_prepend_manager.registered_methods.include?(method_name)

            _apply_validation(method_name)
            super
          end

          def inherited(subclass)
            super

            if defined?(@contract_class)
              subclass.instance_variable_set(:@contract_class, @contract_class)
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

              if args.empty?
                # The keyword arguments are the input.
                super(**step(validate(kwargs)), &block)
              else
                # The last positional argument is the input. Pass through all other args.
                *rest, input = args
                super(*rest, step(validate(input)), **kwargs, &block)
              end
            end
          end
        end
      end
    end
  end
end
