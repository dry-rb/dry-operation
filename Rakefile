# frozen_string_literal: true

require "bundler/setup"
require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "yard"

RSpec::Core::RakeTask.new { |task| task.verbose = false }
RuboCop::RakeTask.new
YARD::Rake::YardocTask.new do |task|
  task.options = %w[--fail-on-warning --no-output]
end

desc "Run code quality checks"
task lint: %i[rubocop yard]

task default: %i[lint spec]
