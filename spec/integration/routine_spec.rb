# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Routines" do
  include Dry::Monads[:result]

  it "mounts routine and launches operation based on routine content" do
    sum_klass = Class.new do
      include Dry::Operation::Plugins::Routine
      include Dry::Monads[:result]

      define_method :call do
        Success(routine.elements.sum)
      end
    end

    counter_klass = Class.new do
      include Dry::Operation::Plugins::Routine
      include Dry::Monads[:result]

      define_method :call do
        Success(routine.elements.size)
      end
    end

    operation_klass = Class.new(Dry::Operation) do
      include Dry::Monads[:result]

      define_method :call do
        steps do
          v = step sum_calculator.call
          n = step counter.call
          step avg(v, n)
        end
      end

      define_method(:sum_calculator) { sum_klass.new }
      define_method(:counter) { counter_klass.new }
      define_method :avg do |v, n|
        Success(v.to_f / n)
      end
    end

    routine_klass = Class.new(Dry::Operation::Routine) do
      attr_reader :elements

      define_method :initialize do |elements|
        @elements = elements
      end

      define_method :callee do
        operation_klass.new
      end
    end

    expect(routine_klass.new(1..25).resume).to eq(Success(13))
  end
end
