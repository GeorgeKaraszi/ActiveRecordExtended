# frozen_string_literal: true

module PostgresExtended
  module WhereChainDecorator
    def overlap(opts, *rest)
      substitute_comparisons(opts, rest, Arel::Nodes::Overlap, "overlap")
    end

    private

    def left_column(rel)
      @scope.klass.columns_hash[rel.left.name] || @scope.klass.columns_hash[rel.left.relation.name]
    end

    def substitute_comparisons(opts, rest, arel_node_class, method)
      build_where_chain(opts, rest) do |rel|
        case rel
        when Arel::Nodes::In, Arel::Nodes::Equality
          arel_node_class.new(rel.left, rel.right)
        else
          raise ArgumentError, "Invalid argument for .where.#{method}(), got #{rel.class}"
        end
      end
    end
  end
end

module ActiveRecord
  module QueryMethods
    class WhereChain
      prepend PostgresExtended::WhereChainDecorator

      def build_where_chain(opts, rest, &block)
        where_clause = @scope.send(:where_clause_factory).build(opts, rest)
        @scope.tap do |scope|
          scope.references!(PredicateBuilder.references(opts)) if opts.is_a?(Hash)
          scope.where_clause += where_clause.modified_predicates(&block)
        end
      end
    end
  end
end
