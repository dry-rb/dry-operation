# frozen_string_literal: true

require "bundler/setup"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new { |task| task.verbose = false }
RuboCop::RakeTask.new

desc "Run code quality checks"
task lint: %i[rubocop]

task default: %i[lint spec]
