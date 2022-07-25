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
      def merge
        merge_ctes!
        merge_union!
        merge_windows!
        super
      end

      def merge_union!
        return if other.unionize_storage.empty?

        relation.union_values          += other.union_values
        relation.union_operations      += other.union_operations
        relation.union_ordering_values += other.union_ordering_values
      end

      def merge_windows!
        return unless other.window_values?

        relation.window_values |= other.window_values
      end

      def merge_ctes!
        return unless other.with_values?

        if other.recursive_value? && !relation.recursive_value?
          relation.with!(:chain).recursive(other.cte)
        else
          relation.with!(other.cte)
        end
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
