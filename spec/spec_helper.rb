# frozen_string_literal: true

# require "bundler/setup"
require "active_record"
require "database_cleaner"

unless ENV["DATABASE_URL"]
  require "dotenv"
  Dotenv.load
end

DatabaseCleaner.strategy = :deletion
ActiveRecord::Base.establish_connection(ENV["DATABASE_URL"])

require "postgres_extended"

class Person < ActiveRecord::Base
  has_many :hm_tags, class_name: "Tag"
  has_and_belongs_to_many :habtm_tags, class_name: "Tag"

  def self.wicked_people
    includes(:habtm_tags).where(tags: { categories: %w[wicked awesome] })
  end
end

class Tag < ActiveRecord::Base
  belongs_to :person
end

class ParentTag < Tag
end

class ChildTag < Tag
  belongs_to :parent_tag, foreign_key: :parent_id
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end
