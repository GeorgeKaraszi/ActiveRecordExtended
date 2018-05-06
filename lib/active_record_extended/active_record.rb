# frozen_string_literal: true

require "active_record"

require "active_record_extended/predicate_builder/array_handler_decorator"
require "active_record_extended/query_methods/where_chain"
require "active_record_extended/query_methods/either"
require "active_record_extended/query_methods/any_of"

if ActiveRecord::VERSION::MAJOR >= 5
  if ActiveRecord::VERSION::MINOR >= 2
    require "active_record_extended/patch/5_2/where_clause"
  else
    require "active_record_extended/patch/5_1/where_clause"
  end
end
