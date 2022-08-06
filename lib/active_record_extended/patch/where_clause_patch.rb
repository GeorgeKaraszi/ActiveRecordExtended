# frozen_string_literal: true

module ActiveRecordExtended
  module Patch
    module WhereClausePatch
      def modified_predicates(&block)
        ActiveRecord::Relation::WhereClause.new(predicates.map(&block))
      end
    end
  end
end

ActiveRecord::Relation::WhereClause.prepend(ActiveRecordExtended::Patch::WhereClausePatch)
