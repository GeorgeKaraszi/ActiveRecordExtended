# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module QueryDelegationUnionize
      delegate :union, to: :all
    end

    module MergerUnion
      def normal_values
        super + [:union]
      end
    end

    module Unionize
      class UnionChain
        def initialize(scope)
          @scope = scope
        end

        def all(*args)
          append_union_order!(:union_all, args)
        end

        def except(*args)
          append_union_order!(:except, args)
        end

        def intersect(*args)
          append_union_order!(:intersect, args)
        end

        protected

        def append_union_order!(union_type, args)
          @scope.tap do |scope|
            scope.union_values           += args
            scope.union_operation_values += [union_type]
          end
        end
      end

      def union_values?
        !@values.dig(:unionize, :union_values).presence.nil?
      end

      def union_operation_values?
        !@values.dig(:unionize, :union_operations).presence.nil?
      end

      def union_order_by?
        !@values.dig(:unionize, :order_by).presence.nil?
      end

      def unionized_name?
        !@values.dig(:unionize, :unionized_name).presence.nil?
      end

      def union_values
        unionize_hash[:union_values] || []
      end

      def union_operation_values
        unionize_hash[:union_operations] || []
      end

      def union_order_by
        unionize_hash[:order_by]
      end

      def unionized_name
        unionize_hash[:unionized_name] || @klass.arel_table.name
      end

      def union_order_by=(value)
        unionize_hash![:order_by] = value
      end

      def union_values=(value)
        unionize_hash![:union_values] = value
      end

      def union_operation_values=(value)
        unionize_hash![:union_operations] = value
      end

      def unionized_name=(value)
        unionize_hash![:unionized_name] = value
      end

      def unionize_hash!
        @values[:unionize] ||= {
          union_values:     [],
          union_operations: [],
          order_by:         nil,
          unionized_name:   nil,
        }
      end

      def unionize_hash
        @values[:unionize] || {}
      end

      def union(opts = :chain, *args)
        return UnionChain.new(spawn) if opts == :chain
        opts.nil? ? self : spawn.union!(opts, *args)
      end

      def union!(opts = :chain, *args)
        return UnionChain.new(self) if opts == :chain
        self.union_values           += [opts] + args
        self.union_operation_values += [:union]
        self
      end

      def build_arel(*aliases)
        super.tap do |arel|
          build_unions(arel) if union_values?
        end
      end

      def unionize_nodes(left, right, operation)
        case operation
        when :union_all
          Arel::Nodes::UnionAll.new(left, right)
        when :except
          Arel::Nodes::Except.new(left, right)
        when :intersect
          Arel::Nodes::Intersect.new(left, right)
        else
          Arel::Nodes::Union.new(left, right)
        end
      end

      def build_union_relationships(arel)
        uvs        = union_values.map(&:arel)
        union_node = unionize_nodes(arel, uvs.shift, union_operation_values.shift)

        uvs.each do |arel_relation|
          union_node = unionize_nodes(union_node, arel_relation, union_operation_values.shift)
        end

        union_node
      end

      def build_unions(arel)
        return unless union_values?

        table_name   = unionized_name
        built_unions = build_union_relationships(arel.dup)
        from         = Arel::Nodes::As.new(built_unions, Arel::Nodes::SqlLiteral.new(table_name))
        arel.from(from)
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::Unionize)
ActiveRecord::Relation::Merger.prepend(ActiveRecordExtended::QueryMethods::MergerUnion)
ActiveRecord::Querying.prepend(ActiveRecordExtended::QueryMethods::QueryDelegationUnionize)
