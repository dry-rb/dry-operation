# frozen_string_literal: true

require "dry/operation/errors"

module Dry
  class Operation
    module ClassContext
      # Dispatches a failure result to an operation instance's `#on_failure`
      # hook, supporting several signatures:
      #
      #   def on_failure(failure)
      #   def on_failure(failure, method_name)
      #   def on_failure(failure, step_name:)
      #   def on_failure(failure, method_name:)
      #   def on_failure(failure, step_name:, method_name:)
      #
      # @api private
      module FailureHookDispatcher
        FAILURE_HOOK_METHOD_NAME = :on_failure

        SUPPORTED_KWARGS = %i[step_name method_name].freeze
        private_constant :SUPPORTED_KWARGS

        class << self
          def call(instance, method_name:, step_name:, result:)
            return unless result.is_a?(Dry::Monads::Result::Failure)

            hook = lookup_hook(instance)
            return unless hook

            invoke_hook(hook, failure: result.failure, step_name: step_name, method_name: method_name)
          end

          private

          def lookup_hook(instance)
            return unless (instance.methods + instance.private_methods).include?(FAILURE_HOOK_METHOD_NAME)

            instance.method(FAILURE_HOOK_METHOD_NAME)
          end

          # Dispatches to the hook based on its positional params arity.
          #
          # - Arity of 1: modern form. The hook receives `failure`, plus whichever of `step_name:`
          #   and `method_name:` is explicitly accepted. When it accepts neither, the slice is
          #   empty and `**{}` makes this equivalent to a plain `hook.(failure)` call.
          # - Arity of 2: legacy form. The second positional is always `method_name`. Reject any
          #   kwargs here, because mixing the two styles would be ambiguous about which identifier
          #   the second positional carries.
          # - Any other arity is unsupported and rejected.
          def invoke_hook(hook, failure:, step_name:, method_name:)
            positional, accepted_kwargs = parse_signature(hook)

            case positional
            when 1
              kwargs = {step_name:, method_name:}.slice(*accepted_kwargs)
              hook.(failure, **kwargs)
            when 2
              raise FailureHookArityError.new(hook: hook) unless accepted_kwargs.empty?

              hook.(failure, method_name)
            else
              raise FailureHookArityError.new(hook: hook)
            end
          end

          # Returns [positional_count, kwargs_array] from the failure hook method's `parameters`.
          def parse_signature(hook)
            positional = 0
            kwargs = []

            hook.parameters.each do |type, name|
              case type
              when :req, :opt then positional += 1
              when :key, :keyreq then kwargs << name
              else raise FailureHookArityError.new(hook: hook)
              end
            end

            raise FailureHookArityError.new(hook: hook) if (kwargs - SUPPORTED_KWARGS).any?

            [positional, kwargs]
          end
        end
      end
    end
  end
end
