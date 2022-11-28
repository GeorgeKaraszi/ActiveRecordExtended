# frozen_string_literal: true

module ActiveRecordExtended
  module Patch
    module RelationPatch
      module QueryDelegation
        AR_EX_QUERY_METHODS = (
          [
            :with, :define_window, :select_window, :foster_select,
            :either_join, :either_joins, :either_order, :either_orders
          ] +
          ActiveRecordExtended::QueryMethods::Unionize::UNIONIZE_METHODS +
          ActiveRecordExtended::QueryMethods::Json::JSON_QUERY_METHODS
        ).freeze

        delegate(*AR_EX_QUERY_METHODS, to: :all)
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

          return relation.with!.recursive(other.cte) if other.recursive_value? && !relation.recursive_value?

          merge_by_values(relation, other)
        end

        private

        # Merge other's with_values one at a time to ensure materialized keys are set properly
        def merge_by_values(relation, other)
          other.cte.with_values.each do |name, expression|
            relation = if other.cte.materialized_key?(name)
              relation.with!.materialized(name => expression)
            elsif other.cte.not_materialized_key?(name)
              relation.with!.not_materialized(name => expression)
            else
              relation.with!(name => expression)
            end
          end

          relation
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
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::Patch::RelationPatch::ArelBuildPatch)
ActiveRecord::Relation::Merger.prepend(ActiveRecordExtended::Patch::RelationPatch::Merger)
ActiveRecord::Base.extend(ActiveRecordExtended::Patch::RelationPatch::QueryDelegation)
