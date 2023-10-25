# frozen_string_literal: true

module Dry
  class Operation
    module ClassContext
      # @api private
      class StepsMethodPrepender < Module
        def initialize(method:)
          super()
          @method = method
        end

        def included(klass)
          klass.prepend(mod)
        end

        private

        def mod
          @module ||= Module.new.tap do |mod|
            mod.define_method(@method) do |*args, **kwargs, &block|
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
