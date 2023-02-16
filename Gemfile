# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

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
  gem "rspec-sqlimit"
end

gemspec
