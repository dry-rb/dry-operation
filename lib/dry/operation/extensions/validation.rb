# frozen_string_literal: true

begin
  require "dry/validation"
rescue LoadError
  raise Dry::Operation::MissingDependencyError.new(gem: "dry-validation", extension: "Validation")
end

module Dry
  class Operation
    module Extensions
      # Add validation support to operations using dry-validation
      #
      # When this extension is included, you can use class-level `params`, `schema`,
      # and `contract` methods to define validation rules for your operation's inputs.
      #
      # @see https://dry-rb.org/gems/dry-validation/
      module Validation
        CONTRACT_CLASS_NAME = "Contract"

        def self.included(klass)
          klass.extend(ClassMethods)
          klass.prepend(InstanceMethods)
        end

        module InstanceMethods
          include Dry::Monads::Result::Mixin

          private

          # Validates input against the resolved contract
          #
          # @param input [Hash] The input to validate
          # @return [Dry::Monads::Result] Success with validated params or Failure with result
          # @api private
          def __validate__(input)
            contract = __resolve_contract__

            return Success(input) unless contract

            result = contract.call(input)

            if result.success?
              Success(result.to_h)
            else
              Failure[:invalid, result]
            end
          end

          # Resolves the contract to use for validation
          #
          # Uses injected @contract if present, otherwise lazily instantiates
          # from the class-level _contract_class
          #
          # @return [Dry::Validation::Contract, nil]
          # @api private
          def __resolve_contract__
            return @contract if defined?(@contract)

            contract_class = self.class._contract_class
            return unless contract_class

            @_contract_instance ||= contract_class.new
          end
        end

        module ClassMethods
          # Define validation rules using params DSL (includes coercion)
          #
          # @param klass [Class, nil] A Dry::Validation::Contract subclass to use
          # @yield Block for defining params validation rules
          # @return [void]
          def params(klass = nil, &block)
            if klass.nil?
              klass = Class.new(Dry::Validation::Contract) do
                params(&block)
              end
              const_set(CONTRACT_CLASS_NAME, klass)
            end

            @_contract_class = klass
            _apply_validation
          end

          # Define validation rules using schema DSL (strict types, no coercion)
          #
          # @param klass [Class, nil] A Dry::Validation::Contract subclass to use
          # @yield Block for defining schema validation rules
          # @return [void]
          def schema(klass = nil, &block)
            if klass.nil?
              klass = Class.new(Dry::Validation::Contract) do
                schema(&block)
              end
              const_set(CONTRACT_CLASS_NAME, klass)
            end

            @_contract_class = klass
            _apply_validation
          end

          # Define validation rules using full contract DSL
          #
          # @param klass [Class, nil] A Dry::Validation::Contract subclass to use
          # @yield Block for defining contract rules
          # @return [void]
          def contract(klass = nil, &block)
            if klass.nil?
              klass = Class.new(Dry::Validation::Contract, &block)
              const_set(CONTRACT_CLASS_NAME, klass)
            end

            @_contract_class = klass
            _apply_validation
          end

          # @api private
          attr_reader :_contract_class

          # @api private
          def _validation_wrapped_methods
            @_validation_wrapped_methods ||= []
          end

          # @api private
          def _apply_validation
            methods_to_wrap = @_prepend_manager.instance_variable_get(:@methods_to_prepend)

            methods_to_wrap.each do |method_name|
              _prepend_validation_for(method_name)
            end
          end

          # @api private
          def method_added(method_name)
            return super unless @_contract_class

            methods_to_wrap = @_prepend_manager.instance_variable_get(:@methods_to_prepend)

            if methods_to_wrap.include?(method_name)
              _prepend_validation_for(method_name)
            end

            super
          end

          # @api private
          def inherited(subclass)
            super
            if defined?(@_contract_class) && @_contract_class
              subclass.instance_variable_set(:@_contract_class, @_contract_class)
            end
          end

          private

          # @api private
          def _prepend_validation_for(method_name)
            return if _validation_wrapped_methods.include?(method_name)
            return unless instance_methods.include?(method_name)

            prepend(Extensions::Validation.create_validator_for(method_name))
            _validation_wrapped_methods << method_name
          end
        end

        # @api private
        def self.create_validator_for(method_name)
          Module.new do
            define_method(method_name) do |input = {}, *rest, **kwargs, &block|
              use_kwargs = !kwargs.empty? && input.empty? && rest.empty?
              actual_input = use_kwargs ? kwargs : input

              validation_result = __validate__(actual_input)

              case validation_result
              when Dry::Monads::Success
                validated_input = validation_result.value!

                if use_kwargs
                  super(**validated_input, &block)
                else
                  super(validated_input, *rest, **kwargs, &block)
                end
              when Dry::Monads::Failure
                throw_failure(validation_result)
              end
            end
          end
        end
      end
    end
  end
end
