# frozen_string_literal: true

module Dry
  class Operation
    # Methods to prepend have already been defined
    class MethodsToPrependAlreadyDefinedError < ::StandardError
      def initialize(methods:)
        super <<~MSG
          '.operate_on' must be called before the given methods are defined.
          The following methods have already been defined: #{methods.join(", ")}
        MSG
      end
    end

    # Configuring prepending after a method has already been prepended
    class PrependConfigurationError < ::StandardError
      def initialize(methods:)
        super <<~MSG
          '.operate_on' and '.skip_prepending' can't be called after any methods\
          in the class have already been prepended.
          The following methods have already been prepended: #{methods.join(", ")}
        MSG
      end
    end

    # Missing dependency required by an extension
    class MissingDependencyError < ::StandardError
      def initialize(gem:, extension:)
        super <<~MSG
          To use the #{extension} extension, you first need to install the \
          #{gem} gem. Please, add it to your Gemfile and run bundle install
        MSG
      end
    end

    # An error related to an extension
    class ExtensionError < ::StandardError; end

    # Defined failure hook has wrong arity
    class FailureHookArityError < ::StandardError
      def initialize(hook:)
        super <<~MSG
          ##{hook.name} must accept 1 (failure) or 2 (failure, method name) \
          arguments, but its arity is #{hook.arity}
        MSG
      end
    end
  end
end
