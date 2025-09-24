# frozen_string_literal: true

require_relative "support/coverage"
require_relative "support/warnings"

Bundler.require :tools

require "dry/operation"
require "dry/operation/extensions/active_record"
require "dry/operation/extensions/rom"
require "dry/operation/extensions/sequel"

SPEC_ROOT = Pathname(__dir__).realpath.freeze

Dir.glob(SPEC_ROOT / "support" / "**" / "*.rb").each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = "./tmp/rspec-examples.txt"
  config.formatter = :progress
  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
    mocks.verify_partial_doubles = true
  end
end
