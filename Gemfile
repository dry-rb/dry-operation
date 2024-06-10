# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :tools do
  gem "debug"
end

group :docs do
  gem "redcarpet", platform: :mri
  gem "yard"
  gem "yard-junk"
end

group :development do
  gem "rake"
  gem "rubocop"
end

group :test do
  gem "guard-rspec"
  gem "rspec"
  gem "simplecov"
end

group :development, :test do
  gem "rom-sql"
  gem "sqlite3"
end
