# frozen_string_literal: true

require "active_record_extended/query_methods/window"
require "active_record_extended/query_methods/unionize"
require "active_record_extended/query_methods/json"

module ActiveRecordExtended
  module RelationPatch
    module QueryDelegation
      delegate :with, :define_window, :select_window, :foster_select, to: :all
      delegate(*::ActiveRecordExtended::QueryMethods::Unionize::UNIONIZE_METHODS, to: :all)
      delegate(*::ActiveRecordExtended::QueryMethods::Json::JSON_QUERY_METHODS, to: :all)
    end

    module Merger
      def normal_values
        super + [:with, :union, :define_window]
      end
    end

    module ArelBuildPatch
      def build_arel(*aliases)
        super.tap do |arel|
          build_windows(arel) if window_values?
          build_unions(arel)  if union_values?
          build_with(arel)    if with_values?
        end
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::RelationPatch::ArelBuildPatch)
ActiveRecord::Relation::Merger.prepend(ActiveRecordExtended::RelationPatch::Merger)
ActiveRecord::Querying.prepend(ActiveRecordExtended::RelationPatch::QueryDelegation)
