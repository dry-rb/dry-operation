# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::Sequel do
  describe "#transaction" do
    it "raises a meaningful error when #db method is not implemented" do
      instance = Class.new(Dry::Operation).include(Dry::Operation::Extensions::Sequel).new

      expect { instance.transaction {} }.to raise_error(
        Dry::Operation::ExtensionError,
        /you need to define a #db method/
      )
    end

    it "forwards options to Sequel transaction call" do
      db = double(:db)
      instance = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Sequel

        attr_reader :db

        def initialize(db)
          super()
          @db = db
        end
      end.new(db)

      expect(db).to receive(:transaction).with(isolation: :serializable)
      instance.transaction(isolation: :serializable) {}
    end

    it "merges options with default options" do
      db = double(:db)
      instance = Class.new(Dry::Operation) do
        include Dry::Operation::Extensions::Sequel[savepoint: true]

        attr_reader :db

        def initialize(db)
          super()
          @db = db
        end
      end.new(db)

      expect(db).to receive(:transaction).with(savepoint: true, isolation: :serializable)
      instance.transaction(isolation: :serializable) {}
    end
  end
end
