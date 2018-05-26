# frozen_string_literal: true

require "active_record"
require "active_record/relation"
require "active_record/relation/query_methods"

require "active_record_extended/predicate_builder/array_handler_decorator"
Dir["#{File.dirname(__FILE__)}/query_methods/**/*.rb"].each { |f| require File.expand_path(f) }

if ActiveRecord::VERSION::MAJOR == 5 && ActiveRecord::VERSION::MINOR <= 1
  if ActiveRecord::VERSION::MINOR.zero?
    require "active_record_extended/patch/5_0/predicate_builder_decorator"
  end
  require "active_record_extended/patch/5_1/where_clause"
elsif ActiveRecord::VERSION::MAJOR >= 5
  require "active_record_extended/patch/5_2/where_clause"
end
