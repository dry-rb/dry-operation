# frozen_string_literal: true

module Dry
  class Operation
    class Error < ::StandardError; end

    # Methods to prepend have already been defined
    class MethodsToPrependAlreadyDefinedError < Error
      def initialize(methods:)
        super <<~MSG
          '.operate_on' must be called before the given methods are defined.
          The following methods have already been defined: #{methods.join(", ")}
        MSG
      end
    end

    # Configuring prepending after a method has already been prepended
    class PrependConfigurationError < Error
      def initialize(methods:)
        super <<~MSG
          '.operate_on' and '.skip_prepending' can't be called after any methods\
          in the class have already been prepended.
          The following methods have already been prepended: #{methods.join(", ")}
        MSG
      end
    end

    # Missing dependency required by an extension
    class MissingDependencyError < Error
      def initialize(gem:, extension:)
        super <<~MSG
          To use the #{extension} extension, you first need to install the \
          #{gem} gem. Please, add it to your Gemfile and run bundle install
        MSG
      end
    end

    class InvalidStepResultError < Error
      def initialize(result:)
        super <<~MSG
          Your step must return `Success(..)` or `Failure(..)`, \
          from `Dry::Monads::Result`. Instead, it was `#{result.inspect}`.
        MSG
      end
    end

    # An error related to an extension
    class ExtensionError < ::StandardError; end
  end
end
