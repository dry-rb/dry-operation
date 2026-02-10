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

          # Resolves the contract to use for validation
          #
          # Uses injected @contract if present, otherwise lazily instantiates
          # from the class-level contract_class
          #
          # @return [Dry::Validation::Contract, nil]
          # @api private
          def contract
            return @contract if defined?(@contract)

            @contract = self.class.contract_class&.new
          end

          # Validates input against the resolved contract
          #
          # @param input [Hash] The input to validate
          # @return [Dry::Monads::Result] Success with validated params or Failure with result
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

        module ClassMethods
          # @api private
          attr_reader :contract_class

          # Define validation rules using params DSL (includes coercion)
          #
          # @param klass [Class, nil] A Dry::Validation::Contract subclass to use
          # @yield Block for defining params validation rules
          # @return [void]
          def params(klass = nil, &block)
            if klass.nil?
              klass = Class.new(Dry::Validation::Contract) { params(&block) }
              const_set(CONTRACT_CLASS_NAME, klass)
            end

            @contract_class = klass
            _apply_validation
          end

          # Define validation rules using schema DSL (strict types, no coercion)
          #
          # @param klass [Class, nil] A Dry::Validation::Contract subclass to use
          # @yield Block for defining schema validation rules
          # @return [void]
          def schema(klass = nil, &block)
            if klass.nil?
              klass = Class.new(Dry::Validation::Contract) { schema(&block) }
              const_set(CONTRACT_CLASS_NAME, klass)
            end

            @contract_class = klass
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

            @contract_class = klass
            _apply_validation
          end

          private

          # @api private
          def method_added(method_name)
            return unless @_prepend_manager.registered_methods.include?(method_name)

            _apply_validation(method_name)
            super
          end

          # @api private
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
            method_name = @method_name

            # Capture named kwargs outside the define_method closure, so we only need to search for
            # them once.
            named_kwargs = nil
            find_named_kwargs = method(:find_named_kwargs)

            define_method(method_name) do |input = {}, *rest, **kwargs, &block|
              use_kwargs = !kwargs.empty? && input.empty? && rest.empty?
              actual_input = use_kwargs ? kwargs : input

              validation_result = validate(actual_input)

              case validation_result
              when Dry::Monads::Success
                validated_input = validation_result.value!

                if use_kwargs
                  # Ensure named kwargs from the wrapped method are still passed through, even if
                  # not included in the validation output. This is important for kwargs that exist
                  # for the method's own logic, outside of the scope of validatable input.
                  named_kwargs ||= find_named_kwargs.call(method(method_name).super_method)
                  passthrough_keys = actual_input
                    .slice(*named_kwargs)
                    .select { |k, _| !validated_input.key?(k) }
                  validated_input = passthrough_keys.merge(validated_input)

                  super(**validated_input, &block)
                else
                  super(validated_input, *rest, **kwargs, &block)
                end
              when Dry::Monads::Failure
                throw_failure(validation_result)
              end
            end
          end

          private

          NAMED_KWARG_TYPES = %i[key keyreq].freeze

          def find_named_kwargs(method)
            # Walk up the method chain to find the first method with named kwargs.
            while method
              named_kwargs = method
                .parameters
                .select { |type, _| NAMED_KWARG_TYPES.include?(type) }
                .map(&:last)

              return named_kwargs if named_kwargs.any?

              method = method.super_method
            end

            []
          end
        end
      end
    end
  end
end
