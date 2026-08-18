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
              _check_validation_signature(method_name)

              next if @_validated_methods.include?(method_name)

              prepend ValidationStep.new(method_name)
              @_validated_methods << method_name
            end
          end

          # Fails fast when a contract is defined for a method that can't receive its input.
          def _check_validation_signature(method_name)
            return unless contract_class
            return unless method_defined?(method_name) || private_method_defined?(method_name)

            method = Signature.unwrap(instance_method(method_name))

            return if method.nil? || Signature.accepts_input?(method)

            raise Dry::Operation::ValidationInputError.new(method: method_name)
          end
        end

        # Reflection on the signature of the methods an operation wraps.
        #
        # @api private
        module Signature
          NAMED_KWARG_TYPES = %i[key keyreq].freeze

          KWARG_TYPES = %i[key keyreq keyrest].freeze

          POSITIONAL_TYPES = %i[req opt rest].freeze

          FORWARDING_TYPES = %i[rest keyrest block].freeze

          module_function

          # Walks up the method chain to find the first method with named kwargs.
          def named_kwargs(method)
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

          # Whether the method can take the input to validate, positionally or as kwargs.
          def accepts_input?(method)
            method.parameters.any? do |type, _|
              POSITIONAL_TYPES.include?(type) || KWARG_TYPES.include?(type)
            end
          end

          def accepts_positional_input?(method)
            method.parameters.any? { |type, _| POSITIONAL_TYPES.include?(type) }
          end

          # Walks up the method chain past the generic wrappers that `Dry::Operation` prepends,
          # to find the method declaring the signature the operation was defined with.
          def unwrap(method)
            method = method.super_method while method && forwarding?(method)
            method
          end

          def forwarding?(method)
            parameters = method.parameters

            parameters.any? && parameters.all? { |type, _| FORWARDING_TYPES.include?(type) }
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

          # rubocop:disable Metrics/AbcSize
          # rubocop:disable Metrics/CyclomaticComplexity
          # rubocop:disable Metrics/PerceivedComplexity
          def define_validation_method
            # Cache the reflection outside the method closure so we only perform it once.
            named_kwargs = nil
            wrapped_method = nil

            define_method(@method_name) do |*args, **kwargs, &block|
              # Without a contract there's nothing to validate, so the arguments the method was
              # called with are forwarded untouched.
              return super(*args, **kwargs, &block) unless contract

              wrapped_method ||= Signature.unwrap(method(__method__).super_method)

              if wrapped_method && !Signature.accepts_input?(wrapped_method)
                raise Dry::Operation::ValidationInputError.new(method: __method__)
              end

              input, *rest = args
              input = {} if args.empty?
              use_kwargs = !kwargs.empty? && input.empty? && rest.empty?

              validation_result = validate(use_kwargs ? kwargs : input)
              throw_failure(validation_result) if validation_result.failure?

              validated_input = validation_result.value!

              if use_kwargs
                # Ensure named kwargs from the wrapped method are still passed through even if
                # they are not in the validation output. This is important for kwargs that exist
                # to serve the method's own logic, separate to the scope of validatable input.
                named_kwargs ||= Signature.named_kwargs(method(__method__).super_method)
                passthrough_keys = kwargs
                  .slice(*named_kwargs)
                  .reject { |k, _| validated_input.key?(k) }

                super(**passthrough_keys.merge(validated_input), &block)
              elsif args.empty? && kwargs.empty?
                # The method was called without arguments, so pass the validated input along in
                # whichever form the method accepts it.
                if wrapped_method.nil? || Signature.accepts_positional_input?(wrapped_method)
                  super(validated_input, &block)
                else
                  super(**validated_input, &block)
                end
              else
                super(validated_input, *rest, **kwargs, &block)
              end
            end
          end
          # rubocop:enable Metrics/AbcSize
          # rubocop:enable Metrics/CyclomaticComplexity
          # rubocop:enable Metrics/PerceivedComplexity
        end
      end
    end
  end
end
