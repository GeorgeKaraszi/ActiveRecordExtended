# frozen_string_literal: true

require "active_record_extended/query_methods/unionize"
require "active_record_extended/query_methods/json"

module ActiveRecordExtended
  module RelationPatch
    module QueryDelegation
      delegate :with, to: :all
      delegate(*::ActiveRecordExtended::QueryMethods::Unionize::UNIONIZE_METHODS, to: :all)
      delegate(*::ActiveRecordExtended::QueryMethods::Json::JSON_QUERY_METHODS, to: :all)
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
