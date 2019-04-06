# frozen_string_literal: true

# TODO: Remove this when ruby 2.3 support is dropped
unless Hash.instance_methods(false).include?(:compact!)
  require "active_support/all"
end

require "active_record"
require "active_record/relation"
require "active_record/relation/merger"
require "active_record/relation/query_methods"

require "active_record_extended/predicate_builder/array_handler_decorator"

require "active_record_extended/active_record/relation_patch"

require "active_record_extended/query_methods/where_chain"
require "active_record_extended/query_methods/with_cte"
require "active_record_extended/query_methods/unionize"
require "active_record_extended/query_methods/any_of"
require "active_record_extended/query_methods/either"
require "active_record_extended/query_methods/inet"
require "active_record_extended/query_methods/json"
require "active_record_extended/query_methods/select"

if ActiveRecord::VERSION::MAJOR == 5 && ActiveRecord::VERSION::MINOR <= 1
  if ActiveRecord::VERSION::MINOR.zero?
    require "active_record_extended/patch/5_0/regex_match"
    require "active_record_extended/patch/5_0/predicate_builder_decorator"
  end
  require "active_record_extended/patch/5_1/where_clause"
elsif ActiveRecord::VERSION::MAJOR >= 5
  require "active_record_extended/patch/5_2/where_clause"
end
