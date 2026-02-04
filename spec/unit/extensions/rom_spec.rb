# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::ROM do
  describe "#transaction" do
    it "raises a meaningful error when #rom method is not implemented" do
      instance = Class.new.include(Dry::Operation::Extensions::ROM).new

      expect { instance.transaction {} }.to raise_error(
        Dry::Operation::ExtensionError,
        /you need to define a #rom method/
      )
    end

    it "forwards options to the ROM gateway transaction call" do
      transaction = double(:transaction)

      gateway = double(:gateway)
      allow(gateway).to receive(:transaction).and_yield(transaction)

      rom = double(:rom, gateways: {default: gateway})

      instance = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::ROM

        attr_reader :rom

        def initialize(rom)
          super()
          @rom = rom
        end
      end.new(rom)

      expect(gateway).to receive(:transaction).with(isolation: :serializable)
      instance.transaction(isolation: :serializable) {}
    end

    it "merges options with default options" do
      transaction = double(:transaction)

      gateway = double(:gateway)
      allow(gateway).to receive(:transaction).and_yield(transaction)

      rom = double(:rom, gateways: {default: gateway})

      instance = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::ROM[isolation: :serializable]

        attr_reader :rom

        def initialize(rom)
          super()
          @rom = rom
        end
      end.new(rom)

      expect(gateway).to receive(:transaction)
        .with(isolation: :serializable, savepoint: true)

      instance.transaction(savepoint: true) {}
    end

    it "uses a custom gateway when provided" do
      transaction = double(:transaction)

      gateway = double(:gateway)
      allow(gateway).to receive(:transaction).and_yield(transaction)

      rom = double(:rom, gateways: {custom: gateway})

      instance = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::ROM[gateway: :custom]

        attr_reader :rom

        def initialize(rom)
          super()
          @rom = rom
        end
      end.new(rom)

      expect(gateway).to receive(:transaction).with(no_args)
      instance.transaction {}
    end
  end
end
