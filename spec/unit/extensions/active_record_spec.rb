# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::ActiveRecord do
  describe "#transaction" do
    it "forwards options to ActiveRecord transaction call" do
      instance = Class.new(Dry::Operation).include(Dry::Operation::Extensions::ActiveRecord).new

      expect(ActiveRecord::Base).to receive(:transaction).with(requires_new: true)
      instance.transaction(requires_new: true) {}
    end

    it "accepts custom initiator and options" do
      instance = Class.new(Dry::Operation).include(Dry::Operation::Extensions::ActiveRecord).new
      record = double(:transaction)

      expect(record).to receive(:transaction)
      instance.transaction(record) {}
    end

    it "merges options with default options" do
      instance = Class.new(Dry::Operation).include(Dry::Operation::Extensions::ActiveRecord[requires_new: true]).new

      expect(ActiveRecord::Base).to receive(:transaction).with(requires_new: true, isolation: :serializable)
      instance.transaction(isolation: :serializable) {}
    end
  end
end
