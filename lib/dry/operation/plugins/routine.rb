# frozen_string_literal: true

module Dry
  class Operation
    module Plugins
      module Routine
        # Refers to routine in current fiber
        #
        # @return [Routine]
        # @api public
        def routine
          Fiber[:__routine__]
        end
      end

      if defined?(Dry::System::Plugin)
        Dry::System::Plugin.register(:routine, Routine)
      end
    end
  end
end
