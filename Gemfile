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

  # Until ActiveRecord JDBC adapters in version 80.x or 81.x are not release, we are using version from
  # master, as lower versions are incompatible with JRuby 10.1.x, against which we are testing.
  gem "activerecord-jdbcsqlite3-adapter", github: "jruby/activerecord-jdbc-adapter", platform: :jruby
end
