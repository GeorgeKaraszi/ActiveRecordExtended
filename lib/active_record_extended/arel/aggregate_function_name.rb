# frozen_string_literal: true

module Arel
  module Nodes
    class AggregateFunctionName < ::Arel::Nodes::Node
      include Arel::Predications
      include Arel::WindowPredications
      attr_accessor :name, :expressions, :distinct, :orderings

      def initialize(name, expr, distinct = false)
        super()
        @name        = name.to_s.upcase
        @expressions = expr
        @distinct    = distinct
      end

      def order_by(expr)
        @orderings = expr
        self
      end

      def hash
        [@name, @expressions, @distinct, @orderings].hash
      end

      def eql?(other)
        self.class == other.class &&
          expressions == other.expressions &&
          orderings == other.orderings &&
          distinct == other.distinct
      end
      alias == eql?
    end
  end
end
