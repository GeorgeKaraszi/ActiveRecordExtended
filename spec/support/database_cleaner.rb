# frozen_string_literal: true

require "database_cleaner"

DatabaseCleaner.strategy = :truncation

RSpec.configure do |config|
  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end
