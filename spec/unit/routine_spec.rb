# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Routine do
  describe "#resume" do
    it "calls callee" do
      klass = Class.new(Dry::Operation::Routine) do
        def callee
          proc { |n| n + 1 }
        end
      end

      routine = klass.new
      expect(routine.resume(2)).to eq(3)
    end
  end

  describe "#fiber" do
    it "creates fiber with routine context in fiber storage" do
      callee_klass = Class.new do
        def call(n)
          n + Fiber[:__routine__].num
        end
      end

      klass = Class.new(Dry::Operation::Routine) do
        def num
          8
        end

        define_method :callee do
          callee_klass.new
        end
      end

      fiber = klass.new.fiber
      expect(fiber).to be_a(Fiber)
      expect(fiber.resume(1)).to eq(9)
    end
  end

  describe "#schedule" do
    it "creates fiber and starts it" do
      scheduler_klass = Class.new do
        attr_reader :kernel_sleep, :io_wait, :block, :unblock

        def fiber(*args, &block)
          fiber = Fiber.new(&block)
          fiber.resume(*args)
          fiber
        end
      end

      result = Struct.new(:val).new

      klass = Class.new(Dry::Operation::Routine) do
        define_method :callee do
          proc { |n| result.val = n + 5 }
        end
      end

      begin
        Fiber.set_scheduler(scheduler_klass.new)
        expect(klass.new.schedule(5)).to be_a(Fiber)
        expect(result.val).to eq(10)
      ensure
        Fiber.set_scheduler(nil)
      end
    end
  end
end
