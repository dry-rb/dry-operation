# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "dry-operation"
  spec.version = "0.0.0"
  spec.authors = ["dry-rb team"]
  spec.email = ["gems@dry-rb.org"]
  spec.homepage = "https://dry-rb.org/gems/dry-operation"
  spec.summary = "A domain specific language for composable business transaction workflows."
  spec.license = "MIT"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/dry-rb/dry-operation/issues",
    "changelog_uri" => "https://github.com/dry-rb/dry-operation/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://dry-rb.org/gems/dry-operation",
    "funding_uri" => "https://github.com/sponsors/hanami",
    "label" => "dry-operation",
    "source_code_uri" => "https://github.com/dry-rb/dry-operation"
  }

  spec.required_ruby_version = ">= 3.0.0"
  spec.add_dependency "zeitwerk", "~> 2.6"
  spec.add_dependency "dry-monads", "~> 1.6"

  spec.extra_rdoc_files = Dir["README*", "LICENSE*"]
  spec.files = Dir["*.gemspec", "lib/**/*"]
end
