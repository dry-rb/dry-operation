# frozen_string_literal: true

module Dry
  class Operation
    # {Dry::Operation} class context
    module ClassContext
      # Default methods to be prepended unless changed via {.operate_on}
      DEFAULT_METHODS_TO_PREPEND = [:call].freeze

      # Configures the instance methods to be prepended
      #
      # The given methods will be prepended with a wrapper that calls {#steps}
      # before calling the original method.
      #
      # This method must be called before defining any of the methods to be
      # prepended or before prepending any other method.
      #
      # @param methods [Array<Symbol>] methods to prepend
      # @raise [MethodsToPrependAlreadyDefinedError] if any of the methods have
      #  already been defined in self
      # @raise [PrependConfigurationError] if there's already a prepended method
      def operate_on(*methods)
        @_prepend_manager.register(*methods)
      end

      # Skips prepending any method
      #
      # This method must be called before any method is prepended.
      #
      # @raise [PrependConfigurationError] if there's already a prepended method
      def skip_prepending
        @_prepend_manager.void
      end

      # @api private
      def inherited(klass)
        super
        if klass.superclass == Dry::Operation
          ClassContext.directly_inherited(klass)
        else
          ClassContext.indirectly_inherited(klass)
        end
      end

      # @api private
      def self.directly_inherited(klass)
        klass.extend(MethodAddedHook)
        klass.instance_variable_set(
          :@_prepend_manager,
          PrependManager.new(klass: klass, methods_to_prepend: DEFAULT_METHODS_TO_PREPEND)
        )
      end

      # @api private
      def self.indirectly_inherited(klass)
        klass.instance_variable_set(
          :@_prepend_manager,
          klass.superclass.instance_variable_get(:@_prepend_manager).for_subclass(klass)
        )
      end

      # @api private
      module MethodAddedHook
        def method_added(method)
          super

          @_prepend_manager.call(method: method)
        end
      end
    end
  end
end
