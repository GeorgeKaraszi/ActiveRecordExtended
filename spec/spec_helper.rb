# frozen_string_literal: true

require "simplecov"
SimpleCov.start

require "active_record_extended"
# require "rspec-sqlimit"

unless ENV["DATABASE_URL"]
  require "dotenv"
  Dotenv.load
end

ActiveRecord::Base.establish_connection(ENV["DATABASE_URL"])

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require File.expand_path(f) }
Dir["#{File.dirname(__FILE__)}/**/*examples.rb"].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
