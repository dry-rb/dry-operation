# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::ActiveRecord do
  describe "#transaction" do
    it "ensures sub-transaction for nested transaction" do
      instance = Class.new.include(Dry::Operation::Extensions::ActiveRecord).new

      expect(ActiveRecord::Base).to receive(:transaction).with(requires_new: true)
      instance.transaction {}
    end
  end
end
