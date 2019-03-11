# frozen_string_literal: true

module ActiveRecordExtended
  module RelationPatch
    module QueryDelegation
      delegate :with, :union, :to_union_sql, to: :all

      if defined?(Niceql)
        delegate :to_nice_sql, to: :all
      end
    end

    module Merger
      def normal_values
        super + [:with, :union]
      end
    end

    module ArelBuildPatch
      def build_arel(*aliases)
        super.tap do |arel|
          build_unions(arel) if union_values?
          build_with(arel)   if with_values?
        end
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::RelationPatch::ArelBuildPatch)
ActiveRecord::Relation::Merger.prepend(ActiveRecordExtended::RelationPatch::Merger)
ActiveRecord::Querying.prepend(ActiveRecordExtended::RelationPatch::QueryDelegation)
