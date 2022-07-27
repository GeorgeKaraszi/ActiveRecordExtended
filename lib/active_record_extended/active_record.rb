# frozen_string_literal: true

require "active_record"
require "active_record/relation"
require "active_record/relation/merger"
require "active_record/relation/query_methods"

module ActiveRecordExtended
  # TODO: Deprecate <= AR 6.0 methods & routines
  AR_VERSION_GTE_6_1 = Gem::Requirement.new(">= 6.1").satisfied_by?(ActiveRecord.gem_version)
end

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
require "active_record_extended/patch/5_2/where_clause"
