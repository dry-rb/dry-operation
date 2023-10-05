# frozen_string_literal: true

module Dry
  class Operation
    # @api private
    class Prepender < Module
      def self.inherited_hook(klass:, methods:)
        return unless methods.any?

        klass.define_singleton_method(:inherited) do |subklass|
          super(subklass)
          subklass.include(Prepender.new(methods: methods))
        end
      end

      def initialize(methods:)
        super()
        @methods = methods
      end

      def included(klass)
        klass.prepend(mod)
      end

      private

      def mod
        @module ||= Module.new.tap do |mod|
          @methods.each do |method|
            mod.define_method(method) do |*args, **kwargs, &block|
              steps do
                super(*args, **kwargs, &block)
              end
            end
          end
        end
      end
    end
  end
end
