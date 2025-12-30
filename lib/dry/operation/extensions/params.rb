# frozen_string_literal: true

begin
  require "dry/validation"
rescue LoadError
  raise Dry::Operation::MissingDependencyError.new(gem: "dry-validation", extension: "Params")
end

module Dry
  class Operation
    module Extensions
      # Add params validation support to operations using dry-validation
      #
      # When this extension is included, you can use class-level `params` and `contract`
      # methods to define validation rules for your operation's inputs.
      #
      # @see https://dry-rb.org/gems/dry-validation/
      module Params
        # Base params class for operation input validation
        class Params
          # Base validator contract that all param schemas inherit from
          class Validator < Dry::Validation::Contract
          end

          class << self
            # Define validation rules using params DSL
            #
            # @yield Block for defining validation rules
            # @return [Validator] The validator instance
            def params(&block)
              @_validator = Class.new(Validator) do
                params(&block)
              end.new
            end

            # Define validation rules using full contract DSL
            #
            # @yield Block for defining contract rules
            # @return [Validator] The validator instance
            def contract(&block)
              @_validator = Class.new(Validator, &block).new
            end

            # @api private
            attr_reader :_validator
          end
        end

        # Constant for anonymous params class name
        PARAMS_CLASS_NAME = "Params"

        def self.included(klass)
          klass.extend(ClassMethods)
          klass.prepend(InstanceMethods)
        end

        # Instance methods for params validation
        module InstanceMethods
          include Dry::Monads::Result::Mixin

          # Validates input against the params validator
          #
          # @param input [Hash] The input to validate
          # @return [Dry::Monads::Result] Success with validated params or Failure with errors
          # @api private
          def validate_params(input)
            params_class = self.class._params_class

            return Success(input) unless params_class

            validator = params_class._validator

            return Success(input) unless validator

            result = validator.call(input)

            if result.success?
              Success(result.to_h)
            else
              Failure[:invalid_params, result.errors.to_h]
            end
          end
        end

        # Class methods added to the operation class
        module ClassMethods
          # Define params validation for the operation
          #
          # @param klass [Class, nil] A Params subclass to use
          # @yield Block for defining validation rules
          # @return [Class] The params class
          def params(klass = nil, &block)
            if klass.nil?
              klass = const_set(PARAMS_CLASS_NAME, Class.new(Params))
              klass.params(&block)
            end

            @_params_class = klass
            _apply_params_validation
          end

          # Define contract validation for the operation
          #
          # @param klass [Class, nil] A Params subclass to use
          # @yield Block for defining contract rules
          # @return [Class] The params class
          def contract(klass = nil, &block)
            if klass.nil?
              klass = const_set(PARAMS_CLASS_NAME, Class.new(Params))
              klass.contract(&block)
            end

            @_params_class = klass
            _apply_params_validation
          end

          # @api private
          def _params_class
            @_params_class
          end

          # @api private
          def _params_validated_methods
            @_params_validated_methods ||= []
          end

          # @api private
          def _apply_params_validation
            methods_to_wrap = instance_variable_get(:@_prepend_manager)
              &.instance_variable_get(:@methods_to_prepend) || []

            methods_to_wrap.each do |method_name|
              next if _params_validated_methods.include?(method_name)
              next unless instance_methods.include?(method_name)

              prepend(Extensions::Params.create_validator_for(method_name))
              _params_validated_methods << method_name
            end
          end

          # @api private
          def method_added(method_name)
            if @_params_class
              methods_to_wrap = instance_variable_get(:@_prepend_manager)
                &.instance_variable_get(:@methods_to_prepend) || []

              if methods_to_wrap.include?(method_name) && !_params_validated_methods.include?(method_name)
                prepend(Extensions::Params.create_validator_for(method_name))
                _params_validated_methods << method_name
              end
            end

            super
          end

          # @api private
          def inherited(subclass)
            super
            if defined?(@_params_class) && @_params_class
              subclass.instance_variable_set(:@_params_class, @_params_class)
            end
          end
        end

        # @api private
        def self.create_validator_for(method_name)
          Module.new do
            define_method(method_name) do |input = {}, *rest, **kwargs, &block|
              use_kwargs = input.empty? && !kwargs.empty? && rest.empty?
              actual_input = use_kwargs ? kwargs : input

              validation_result = validate_params(actual_input)

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
