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
      # operation instance.
      #
      # @see https://dry-rb.org/gems/dry-validation/
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

          # rubocop:disable Metrics/PerceivedComplexity
          def define_validation_method
            # Cache named kwargs outside the method closure so we only search for them once.
            named_kwargs = nil
            find_named_kwargs = method(:find_named_kwargs)

            define_method(@method_name) do |input = {}, *rest, **kwargs, &block|
              use_kwargs = !kwargs.empty? && input.empty? && rest.empty?
              actual_input = use_kwargs ? kwargs : input

              validation_result = validate(actual_input)

              case validation_result
              when Dry::Monads::Success
                validated_input = validation_result.value!

                if use_kwargs
                  # Ensure named kwargs from the wrapped method are still passed through even if
                  # they are not in the validation output. This is important for kwargs that exist
                  # to serve the method's own logic, separate to the scope of validatable input.
                  named_kwargs ||= find_named_kwargs.call(method(__method__).super_method)
                  passthrough_keys = actual_input
                    .slice(*named_kwargs)
                    .reject { |k, _| validated_input.key?(k) }
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
          # rubocop:enable Metrics/PerceivedComplexity

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
