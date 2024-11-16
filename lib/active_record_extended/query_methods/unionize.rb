# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module Unionize
      UNION_RELATION_METHODS  = [:order_union, :reorder_union, :union_as].freeze
      UNIONIZE_METHODS        = [:union, :union_all, :union_except, :union_intersect].freeze
      DEFAULT_STORAGE_VALUE   = proc { [] }

      class UnionChain
        include ActiveRecordExtended::Utilities::Support
        include ActiveRecordExtended::Utilities::OrderBy

        def initialize(scope)
          @scope = scope
        end

        def as(from_clause_name)
          @scope.unionized_name = from_clause_name.to_s
          @scope
        end
        alias union_as as

        def order(*ordering_args)
          process_ordering_arguments!(ordering_args)
          @scope.union_ordering_values += ordering_args
          @scope
        end
        alias order_union order

        def reorder(*ordering_args)
          @scope.union_ordering_values.clear
          order(*ordering_args)
        end
        alias reorder_union reorder

        def union(*args)
          append_union_order!(:union, args)
          @scope
        end

        def all(*args)
          append_union_order!(:union_all, args)
          @scope
        end
        alias union_all all

        def except(*args)
          append_union_order!(:except, args)
          @scope
        end
        alias union_except except

        def intersect(*args)
          append_union_order!(:intersect, args)
          @scope
        end
        alias union_intersect intersect

        protected

        def append_union_order!(union_type, args)
          args.each { |arg| pipe_cte_with!(arg) }
          flatten_scopes       = flatten_to_sql(args)
          @scope.union_values += flatten_scopes
          calculate_union_operation!(union_type, flatten_scopes.size)
        end

        def calculate_union_operation!(union_type, scope_count)
          scope_count             -= 1 unless @scope.union_operations?
          scope_count              = 1 if scope_count <= 0 && @scope.union_values.size <= 1
          @scope.union_operations += [union_type] * scope_count
        end
      end

      def unionize_storage
        @values.fetch(:unionize, {})
      end

      def unionize_storage!
        @values[:unionize] ||= {
          union_values:          [],
          union_operations:      [],
          union_ordering_values: [],
          unionized_name:        nil
        }
      end

      {
        union_values:          DEFAULT_STORAGE_VALUE,
        union_operations:      DEFAULT_STORAGE_VALUE,
        union_ordering_values: DEFAULT_STORAGE_VALUE,
        unionized_name:        proc { arel_table.name }
      }.each_pair do |method_name, default|
        define_method(method_name) do
          if send(:"#{method_name}?")
            unionize_storage[method_name]
          else
            instance_eval(&default)
          end
        end

        define_method(:"#{method_name}?") do
          unionize_storage.key?(method_name) && !unionize_storage[method_name].presence.nil?
        end

        define_method(:"#{method_name}=") do |value|
          unionize_storage![method_name] = value
        end
      end

      def union(opts = :chain, *args)
        return UnionChain.new(spawn) if :chain == opts

        opts.nil? ? self : spawn.union!(opts, *args, chain_method: __callee__)
      end

      (UNIONIZE_METHODS + UNION_RELATION_METHODS).each do |union_method|
        next if union_method == :union

        alias_method union_method, :union
      end

      def union!(opts = :chain, *args, chain_method: :union)
        union_chain    = UnionChain.new(self)
        chain_method ||= :union
        return union_chain if :chain == opts

        union_chain.public_send(chain_method, *([opts] + args))
      end

      # Will construct *Just* the union SQL statement that was been built thus far
      def to_union_sql
        return unless union_values?

        apply_union_ordering(build_union_nodes!(false)).to_sql
      end

      def to_nice_union_sql(color = true)
        return to_union_sql unless defined?(::Niceql)

        ::Niceql::Prettifier.prettify_sql(to_union_sql, color)
      end

      protected

      def build_unions(arel)
        return unless union_values?

        union_nodes      = apply_union_ordering(build_union_nodes!)
        table_name       = Arel.sql(unionized_name)
        table_alias      = arel.create_table_alias(arel.grouping(union_nodes), table_name)
        arel.from(table_alias)
      end

      # Builds a set of nested nodes that union each other's results
      #
      # Note: Order of chained unions *DOES* matter
      #
      # Example:
      #
      #   User.union(User.select(:id).where(id: 8))
      #       .union(User.select(:id).where(id: 50))
      #       .union.except(User.select(:id).where(id: 8))
      #
      #   #=> [<#User id: 50]]
      #
      #   ```sql
      #   SELECT users.*
      #   FROM(
      #       (
      #         (SELECT users.id FROM users WHERE id = 8)
      #         UNION
      #         (SELECT users.id FROM users WHERE id = 50)
      #       )
      #       EXCEPT
      #       (SELECT users.id FROM users WHERE id = 8)
      #    ) users;
      #   ```

      def build_union_nodes!(raise_error = true)
        unionize_error_or_warn!(raise_error)
        union_values.each_with_index.reduce(nil) do |union_node, (relation_node, index)|
          next resolve_relation_node(relation_node) if union_node.nil? # rubocop:disable Lint/UnmodifiedReduceAccumulator

          operation = union_operations.fetch(index - 1, :union)
          left      = union_node
          right     = resolve_relation_node(relation_node)

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

      # Apply's the allowed ORDER BY to the end of the final union statement
      #
      # Note: This will only apply at the very end of the union statements. Not nested ones.
      #       (I guess you could double nest a union and apply it, but that would be dumb)
      #
      # Example:
      #   User.union(User.select(:id).where(id: 8))
      #       .union(User.select(:id).where(id: 50))
      #       .union.order(id: :desc)
      #  #=> [<#User id: 50>, <#User id: 8>]
      #
      #   ```sql
      #   SELECT users.*
      #   FROM(
      #       (SELECT users.id FROM users WHERE id = 8)
      #       UNION
      #       (SELECT users.id FROM users WHERE id = 50)
      #       ORDER BY id DESC
      #    ) users;
      #   ```
      #
      def apply_union_ordering(union_nodes)
        return union_nodes unless union_ordering_values?

        UnionChain.new(self).inline_order_by(union_nodes, union_ordering_values)
      end

      private

      def unionize_error_or_warn!(raise_error = true)
        if raise_error && union_values.size <= 1
          raise ArgumentError.new("You are required to provide 2 or more unions to join!")
        elsif !raise_error && union_values.size <= 1
          warn("Warning: You are required to provide 2 or more unions to join.")
        end
      end

      def resolve_relation_node(relation_node)
        case relation_node
        when String
          Arel::Nodes::Grouping.new(Arel.sql(relation_node))
        else
          relation_node.arel
        end
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::Unionize)
