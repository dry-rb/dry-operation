# frozen_string_literal: true

module Dry
  class Operation
    class Routine
      # Simple implementation of fiber storage
      #
      # Replacement until fiber native storage appears (until the ruby version 3.3.0)
      # https://docs.ruby-lang.org/en/master/Fiber.html#method-i-storage
      module StorageMethods
        module InstanceMethods
          def __storage__
            @__storage__ ||= {}
          end
        end

        module ClassMethods
          def [](name)
            current.__storage__[name]
          end

          def []=(name, obj)
            current.__storage__[name] = obj
          end
        end

        if  Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.3.0") ||
            ENV["FORCE_DRY_OPERATION_ROUTINE_STORAGE"] == "true"
          Fiber.class_eval do
            extend ClassMethods
            prepend InstanceMethods
          end
        end
      end
    end
  end
end
