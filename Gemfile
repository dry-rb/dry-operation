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

  # Use a prerelease, since older adapter versions do not work with JRuby 10.1.x, which is what we
  # test against.
  #
  # (Do not install this adapter from git. Its jar must be compiled at install time, and Bundler on
  # JRuby 10.1.2+ skips that step, so the adapter fails to load.)
  gem "activerecord-jdbcsqlite3-adapter", "81.0.pre1", platform: :jruby
end
