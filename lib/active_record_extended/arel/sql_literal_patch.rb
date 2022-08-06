# frozen_string_literal: true

require "arel/nodes/sql_literal"

# CTE alias fix for Rails 6.1
module Arel
  module Nodes
    module SqlLiteralPatch
      def name
        self
      end
    end
  end
end

Arel::Nodes::SqlLiteral.prepend(Arel::Nodes::SqlLiteralPatch)
