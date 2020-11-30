# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

group :development, :test do
  gem "rubocop", require: false
  gem "rubocop-performance", require: false

  gem "dotenv"

  gem "byebug"
  gem "niceql"
  gem "pry", "~> 0.11.3"
  gem "pry-byebug", "~> 3.5", ">= 3.5.1"
end

gemspec
