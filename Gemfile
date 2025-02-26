# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem "bundler", ">= 2.2", "< 3.0"

# Required for Ruby 3.3+ to fix runtime warnings
gem "base64"
gem "bigdecimal"
gem "mutex_m"

gem "database_cleaner", "~> 2.0"
gem "rake", ">= 10.0"
gem "rspec", "~> 3.0"
# gem "rspec-sqlimit", "~> 0.0.5"
gem "simplecov", "~> 0.16"

group :development, :test do
  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rake", require: false
  gem "rubocop-rspec", require: false

  gem "dotenv"

  gem "byebug"
  gem "pry"
  gem "pry-byebug"
  gem "rails_sql_prettifier" # niceql
end

gemspec
