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
          @scope.union_values     += args
          @scope.union_operations += [union_type]
          @scope
        end
      end

      def unionize_storage
        @values.fetch(:unionize, {})
      end

      def unionize_storage!
        @values[:unionize] ||= {
          union_values:     [],
          union_operations: [],
          union_order_by:   nil,
          unionized_name:   nil,
        }
      end

      {
        union_values:     Array,
        union_operations: Array,
        unionized_name:   lambda { |klass| klass.arel_table.name },
        union_order_by:   nil,
      }.each_pair do |method_name, default|
        define_method("#{method_name}?") do
          unionize_storage.key?(method_name) && !unionize_storage[method_name].presence.nil?
        end

        define_method(method_name) do
          unionize_storage[method_name].presence || (default.is_a?(Proc) ? default.call(@klass) : default&.new)
        end

        define_method("#{method_name}=") do |value|
          unionize_storage![method_name] = unionize_storage![method_name].is_a?(Array) ? flatten_scopes(value) : value
        end

        next unless default.is_a?(Array)
        define_method("flatten_#{method_name}!") do
          unionize_storage[method_name] =
            unionize_storage[method_name].inject([]) do |new_array, object|
              new_array << object.is_a?(Array)
            end
        end
      end

      def flatten_scopes(values)
        values.inject([]) do |new_ary, value|
          value.is_a?(Array) ? new_ary + flatten_scopes(value) : new_ary << value
        end
      end

      def union(opts = :chain, *args)
        return UnionChain.new(spawn) if opts == :chain
        opts.nil? ? self : spawn.union!(opts, *args)
      end

      def union!(opts = :chain, *args)
        return UnionChain.new(self) if opts == :chain
        self.union_values           += [opts] + args
        self.union_operations       += [:union]
        self
      end

      def build_arel(*aliases)
        super.tap do |arel|
          build_unions(arel) if union_values?
        end
      end

      def build_unions(arel)
        return unless union_values?

        union_nodes  = build_union_nodes(arel.dup)
        from         = Arel::Nodes::As.new(union_nodes, Arel::Nodes::SqlLiteral.new(unionized_name))
        arel.from(from)
      end

      def build_union_nodes(arel)
        # We need to first initialize the initial union between the parent (arel param) and
        # the first child being union'd
        # Afterwords we can begin to nest and append unions in the order for which they were received in.
        union_values.inject(nil) do |union_node, relation_node|
          operation     = union_operations.shift
          left          = union_node || arel
          right         = relation_node.arel

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
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::Unionize)
ActiveRecord::Relation::Merger.prepend(ActiveRecordExtended::QueryMethods::MergerUnion)
ActiveRecord::Querying.prepend(ActiveRecordExtended::QueryMethods::QueryDelegationUnionize)
