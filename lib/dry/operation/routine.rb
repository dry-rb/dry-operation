# frozen_string_literal: true

module Dry
  class Operation
    # Wrapper for complex multi-component operations.
    # It wraps the target operation in fiber and
    # puts self-instance to fiber storage to use the instance as context object
    # providing temporary data and settings for operation participants.
    #
    # @example
    #  class MyMultiOperation < Dry::Operation
    #    def call(input)
    #      steps do
    #        info = step composer.call(input)
    #        result = step reporter.call(info)
    #        result
    #      end
    #    end
    #  end
    #
    #  class Composer
    #    def call(input)
    #     # Dry::Monads::Result::Success or Dry::Monads::Result::Failure
    #    end
    #
    #    def current_vendor
    #      routine.vendor
    #    end
    #  end
    #
    #  class Reporter
    #    def call(info)
    #     # Dry::Monads::Result::Success or Dry::Monads::Result::Failure
    #    end
    #
    #    def current_vendor
    #      routine.vendor
    #    end
    #  end
    #
    #  class Routine < Dry::Operation::Routine
    #    attr_reader :vendor
    #
    #    def initialize(vendor)
    #      @vendor = vendor
    #    end
    #
    #    def callee
    #      MyMultiOperation.new
    #    end
    #  end
    #
    class Routine
      # Launches routine in fiber
      #
      # @return [Object]
      # @api public
      def resume(*args)
        fiber.resume(*args)
      end

      # Prepares routine fiber (without starting)
      #
      # @return [Fiber]
      # @api public
      def fiber
        @fiber ||= Fiber.new(fiber_options, &self)
      end

      # Sends routine to fiber scheduler.
      # Expects fiber scheduler settings.
      #
      # @return [Fiber]
      # @api public
      def schedule(*args)
        Fiber.schedule(*args, &self)
      end

      # to override
      #
      # @return [Proc]
      # @api public
      def callee
        proc {}
      end

      # to override
      # Provides settings to initialize a fiber
      #
      # @return [Hash]
      # @api public
      def fiber_options
        {}
      end

      # @api private
      def to_proc
        proc do |*args|
          Fiber[:__routine__] = self
          callee.call(*args)
        end
      end
    end

    loader.eager_load_dir("#{__dir__}/routine")
  end
end
