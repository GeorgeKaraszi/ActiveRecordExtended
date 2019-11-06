# frozen_string_literal: true

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

if ActiveRecord::VERSION::MAJOR == 5 && ActiveRecord::VERSION::MINOR == 1
  require "active_record_extended/patch/5_1/where_clause"
else
  require "active_record_extended/patch/5_2/where_clause" # Works with Rail 6.0.x too
end
