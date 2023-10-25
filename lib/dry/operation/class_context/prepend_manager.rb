# frozen_string_literal: true

require "dry/operation/errors"

module Dry
  class Operation
    module ClassContext
      # @api private
      class PrependManager
        def initialize(klass:, methods_to_prepend:, prepended_methods: [])
          @klass = klass
          @methods_to_prepend = methods_to_prepend
          @prepended_methods = prepended_methods
        end

        def register(*methods)
          ensure_pristine

          already_defined_methods = methods & @klass.instance_methods(false)
          if already_defined_methods.any?
            raise MethodsToPrependAlreadyDefinedError.new(methods: already_defined_methods)
          else
            @methods_to_prepend = methods
          end
        end

        def void
          ensure_pristine

          @methods_to_prepend = []
        end

        def call(method:)
          return self unless @methods_to_prepend.include?(method)

          @klass.include(MethodPrepender.new(method: method))
          @prepended_methods += [method]
        end

        def for_subclass(subclass)
          self.class.new(
            klass: subclass,
            methods_to_prepend: @methods_to_prepend.dup,
            prepended_methods: []
          )
        end

        private

        def ensure_pristine
          return if @prepended_methods.empty?

          raise PrependConfigurationError.new(methods: @prepended_methods)
        end
      end
    end
  end
end
