# frozen_string_literal: true

module PostgresExtended
  module RelationDecorator
    def modified_predicates(&block)
      ::ActiveRecord::Relation::WhereClause.new(predicates.map(&block), binds)
    end
  end
end

ActiveRecord::Relation::WhereClause.prepend(PostgresExtended::RelationDecorator)
