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

      # rubocop:enable Naming/MethodName
    end
  end
end

Arel::Visitors::PostgreSQL.prepend(PostgresExtended::Visitors::PostgreSQLDecorator)
