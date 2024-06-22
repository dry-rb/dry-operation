# frozen_string_literal: true

require "dry/operation/errors"

module Dry
  class Operation
    module ClassContext
      # @api private
      class StepsMethodPrepender < Module
        FAILURE_HOOK_METHOD_NAME = :on_failure

        RESULT_HANDLER = lambda do |instance, method, result|
          return if result.success? ||
                    !(instance.methods + instance.private_methods).include?(
                      FAILURE_HOOK_METHOD_NAME
                    )

          failure_hook = instance.method(FAILURE_HOOK_METHOD_NAME)
          case failure_hook.arity
          when 1
            failure_hook.(result.failure)
          when 2
            failure_hook.(result.failure, method)
          else
            raise FailureHookArityError.new(hook: failure_hook)
          end
        end

        def initialize(method:, result_handler: RESULT_HANDLER)
          super()
          @method = method
          @result_handler = result_handler
        end

        def included(klass)
          klass.prepend(mod)
        end

        private

        def mod
          @module ||= Module.new.tap do |mod|
            module_exec(@result_handler) do |result_handler|
              mod.define_method(@method) do |*args, **kwargs, &block|
                steps do
                  super(*args, **kwargs, &block)
                end.tap do |result|
                  result_handler.(self, __method__, result)
                end
              end
            end
          end
        end
      end
    end
  end
end
