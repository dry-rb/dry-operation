# frozen_string_literal: true

# This file is synced from hanakai-rb/repo-sync. To update it, edit repo-sync.yml.

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "dry/operation/version"

Gem::Specification.new do |spec|
  spec.name          = "dry-operation"
  spec.authors       = ["Hanakai team"]
  spec.email         = ["info@hanakai.org"]
  spec.license       = "MIT"
  spec.version       = Dry::Operation::VERSION.dup

  spec.summary       = "A domain specific language for composable business transaction workflows."
  spec.description   = spec.summary
  spec.homepage      = "https://dry-rb.org/gems/dry-operation"
  spec.files         = Dir["CHANGELOG.md", "LICENSE", "README.md", "dry-operation.gemspec", "lib/**/*"]
  spec.bindir        = "exe"
  spec.executables   = Dir["exe/*"].map { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = ["README.md", "CHANGELOG.md", "LICENSE"]

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["changelog_uri"]     = "https://github.com/dry-rb/dry-operation/blob/main/CHANGELOG.md"
  spec.metadata["source_code_uri"]   = "https://github.com/dry-rb/dry-operation"
  spec.metadata["bug_tracker_uri"]   = "https://github.com/dry-rb/dry-operation/issues"
  spec.metadata["funding_uri"]       = "https://github.com/sponsors/hanami"

  spec.required_ruby_version = ">= 3.1.0"

  spec.add_runtime_dependency "dry-monads", "~> 1.6"
  spec.add_runtime_dependency "zeitwerk", "~> 2.6"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "yard"
end

