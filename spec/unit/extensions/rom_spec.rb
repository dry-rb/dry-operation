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
  end
end
