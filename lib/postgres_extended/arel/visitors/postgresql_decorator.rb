# frozen_string_literal: true

require "arel/visitors/postgresql"

module PostgresExtended
  module Visitors
    module PostgreSQLDecorator
      private

      # rubocop:disable Naming/MethodName

      def visit_Arel_Nodes_Overlap(object, collector)
        infix_value object, collector, " && "
      end

      def visit_Arel_Nodes_ContainsArray(object, collector)
        infix_value object, collector, " @> "
      end
      alias visit_Arel_Nodes_ContainsHStore visit_Arel_Nodes_ContainsArray

      def visit_Arel_Nodes_Contains(object, collector)
        left_column = object.left.relation.name.classify.constantize.columns.detect do |col|
          matchable_column?(col, object)
        end

        if left_column && (left_column.type == :hstore || left_column.try(:array))
          visit_Arel_Nodes_ContainsArray(object, collector)
        else
          infix_value object, collector, " >> "
        end
      end

      def matchable_column?(col, object)
        col.name == object.left.name.to_s || col.name == object.left.relation.name.to_s
      end

      # rubocop:enable Naming/MethodName
    end
  end
end

Arel::Visitors::PostgreSQL.prepend(PostgresExtended::Visitors::PostgreSQLDecorator)
