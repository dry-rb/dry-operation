# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Operations" do
  include Dry::Monads[:result]

  it "chains successful operations and returns wrapping in a Success" do
    klass = Class.new(Dry::Operation) do
      def add_one_then_two(x)
        steps do
          y = step add_one(x)
          step add_two(y)
        end
      end

      def add_one(x) = Success(x + 1)
      def add_two(x) = Success(x + 2)
    end

    expect(
      klass.new.add_one_then_two(1)
    ).to eq(Success(4))
  end

  it "short-circuits on Failure and returns it" do
    klass = Class.new(Dry::Operation) do
      def divide_by_zero_then_add_one(x)
        steps do
          y = step divide_by_zero(x)
          step inc(y)
        end
      end

      def divide_by_zero(_x) = Failure(:not_possible)
      def add_one(x) = Success(x + 1)
    end

    expect(
      klass.new.divide_by_zero_then_add_one(1)
    ).to eq(Failure(:not_possible))
  end
end
