# frozen_string_literal: true

module ActiveRecordExtended
  module WhereClause
    def modified_predicates(&block)
      ::ActiveRecord::Relation::WhereClause.new(predicates.map(&block))
    end
  end
end

ActiveRecord::Relation::WhereClause.prepend(ActiveRecordExtended::WhereClause)
