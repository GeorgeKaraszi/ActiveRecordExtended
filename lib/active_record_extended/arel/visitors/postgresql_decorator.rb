# frozen_string_literal: true

require "arel/visitors/postgresql"

module ActiveRecordExtended
  module Visitors
    module PostgreSQLDecorator
      private

      # rubocop:disable Naming/MethodName

      def visit_Arel_Nodes_Overlap(object, collector)
        infix_value object, collector, " && "
      end

      def visit_Arel_Nodes_Contains(object, collector)
        left_column = object.left.relation.name.classify.constantize.columns.detect do |col|
          matchable_column?(col, object)
        end

        if %i[hstore jsonb].include?(left_column&.type)
          visit_Arel_Nodes_ContainsHStore(object, collector)
        elsif left_column.try(:array)
          visit_Arel_Nodes_ContainsArray(object, collector)
        else
          infix_value object, collector, " >> "
        end
      end

      def visit_Arel_Nodes_ContainsArray(object, collector)
        infix_value object, collector, " @> "
      end

      def visit_Arel_Nodes_ContainsHStore(object, collector)
        infix_value object, collector, " @> "
      end

      def visit_Arel_Nodes_ContainedInHStore(object, collector)
        infix_value object, collector, " <@ "
      end

      def visit_Arel_Nodes_ContainedInArray(object, collector)
        infix_value object, collector, " <@ "
      end

      def visit_Arel_Nodes_Inet_ContainedWithin(object, collector)
        infix_value object, collector, " << "
      end

      def visit_Arel_Nodes_Inet_ContainedWithinEquals(object, collector)
        infix_value object, collector, " <<= "
      end

      def visit_Arel_Nodes_Inet_ContainsEquals(object, collector)
        infix_value object, collector, " >>= "
      end

      def matchable_column?(col, object)
        col.name == object.left.name.to_s || col.name == object.left.relation.name.to_s
      end

      # rubocop:enable Naming/MethodName
    end
  end
end

Arel::Visitors::PostgreSQL.prepend(ActiveRecordExtended::Visitors::PostgreSQLDecorator)
