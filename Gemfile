# frozen_string_literal: true

source "https://rubygems.org"

eval_gemfile "Gemfile.devtools"

gemspec

group :tools do
  gem "debug", platform: :mri
end

group :docs do
  gem "redcarpet", platform: :mri
  gem "yard"
  gem "yard-junk"
end

group :test do
  gem "guard-rspec"
end

group :development, :test do
  gem "activerecord"
  gem "dry-validation"
  gem "rom-sql"
  gem "sequel"
  gem "sqlite3", platform: :mri
  gem "jdbc-sqlite3", platform: :jruby

  # We track master because no released version of the adapter (80.x or 81.x) works yet with JRuby
  # 10.1.x, which is what we test against.
  #
  # As of 2026-06-07, pin to a commit before jruby/activerecord-jdbc-adapter#1207, which relaxed the
  # activerecord dependency to `~> 8.0` and pulls in activerecord 8.1.x. The adapter's 8.1 support
  # is currently broken for SQLite3 (NoMethodError: undefined method 'mutable?' for nil).
  gem "activerecord-jdbcsqlite3-adapter",
    github: "jruby/activerecord-jdbc-adapter",
    ref: "74aeab07a97001de74591ff5f50a6ff9807e9faa",
    platform: :jruby
end
