# frozen_string_literal: true

require "zeitwerk"

module Dry
  # Main namespace.
  module Operation
    def self.loader
      @loader ||= Zeitwerk::Loader.new.tap do |loader|
        root = File.expand_path "..", __dir__
        loader.inflector = Zeitwerk::GemInflector.new("#{root}/dry/operation.rb")
        loader.tag = "dry-operation"
        loader.push_dir root
      end
    end

    loader.setup
  end
end
