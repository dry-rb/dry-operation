# frozen_string_literal: true

source "https://rubygems.org"

eval_gemfile "Gemfile.devtools"

gemspec

group :tools do
  gem "debug"
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
  gem "rom-sql"
  gem "sequel"
  gem "sqlite3"
end
