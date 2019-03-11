# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module Unionize
      class UnionChain
        def initialize(scope)
          @scope = scope
        end

        def as(from_clause_name)
          @scope.tap { |scope| scope.unionized_name = from_clause_name.to_s }
        end
        alias name as

        def order(*ordering_args)
          process_ordering_arguments!(ordering_args)
          @scope.tap { |scope| scope.union_ordering_values += ordering_args }
        end

        def reorder(*ordering_args)
          @scope.union_ordering_values.clear
          order(*ordering_args)
        end

        def union(*args)
          append_union_order!(:union, args)
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
            flatten_scopes = ::ActiveRecordExtended::Utilities.flatten_to_sql(args)
            scope.union_values += flatten_scopes
            calculate_union_operation!(union_type, flatten_scopes.size, scope)
          end
        end

        def calculate_union_operation!(union_type, scope_count, scope = @scope)
          scope_count           -= 1 unless scope.union_operations?
          scope_count            = 1 if scope_count <= 0 && scope.union_values.size <= 1
          scope.union_operations += [union_type] * scope_count
        end

        # We'll need to preprocess these arguments for allowing `ActiveRecord::Relation#preprocess_order_args`,
        # to check for sanitization issues and convert over to `Arel::Nodes::[Ascending/Descending]`.
        # Without reflecting / prepending the parent's table name.

        if ActiveRecord.gem_version < Gem::Version.new("5.1")
          # TODO: Rails 5.0.x order logic will *always* append the parents name to the column when its an HASH obj
          #       We should really do this stuff better. Maybe even just ignore `preprocess_order_args` altogether?
          #       Maybe I'm just stupidly over paranoid on just the 'ORDER BY' for some odd reason.
          def process_ordering_arguments!(ordering_args)
            ordering_args.flatten!
            ordering_args.compact!
            ordering_args.map! do |arg|
              next sql_literal(arg) unless arg.is_a?(Hash) # ActiveRecord will reflect if an argument is a symbol
              arg.each_with_object([]) do |(field, dir), ordering_object|
                ordering_object << sql_literal(field.to_s).send(dir.to_s.downcase)
              end
            end.flatten!
          end
        else
          def process_ordering_arguments!(ordering_args)
            ordering_args.flatten!
            ordering_args.compact!
            ordering_args.map! do |arg|
              next sql_literal(arg) unless arg.is_a?(Hash) # ActiveRecord will reflect if an argument is a symbol
              arg.each_with_object({}) do |(field, dir), ordering_obj|
                # ActiveRecord will not reflect if the Hash keys are a `Arel::Nodes::SqlLiteral` klass
                ordering_obj[sql_literal(field.to_s)] = dir.to_s.downcase
              end
            end
          end
        end

        def sql_literal(object)
          Arel.sql(object.to_s)
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
          unionized_name:        nil,
        }
      end

      {
        union_values:          Array,
        union_operations:      Array,
        union_ordering_values: Array,
        unionized_name:        lambda { |klass| klass.arel_table.name },
      }.each_pair do |method_name, default|
        define_method(method_name) do
          return unionize_storage[method_name] if send("#{method_name}?")
          (default.is_a?(Proc) ? default.call(@klass) : default.new)
        end

        define_method("#{method_name}?") do
          unionize_storage.key?(method_name) && !unionize_storage[method_name].presence.nil?
        end

        define_method("#{method_name}=") do |value|
          unionize_storage![method_name] = value
        end
      end

      def union(opts = :chain, *args)
        return UnionChain.new(spawn) if opts == :chain
        opts.nil? ? self : spawn.union!(opts, *args)
      end

      def union!(opts = :chain, *args)
        union_chain = UnionChain.new(self)
        opts == :chain ? union_chain : union_chain.union([opts] + args)
      end

      # Will construct *Just* the union SQL statement that was been built thus far
      def to_union_sql
        return unless union_values?
        apply_union_ordering(build_union_nodes!(false)).to_sql
      end

      if defined?(::Niceql)
        def to_nice_union_sql(color = true)
          ::Niceql::Prettifier.prettify_sql(to_union_sql, color)
        end
      end

      protected

      def build_unions(arel = @klass.arel_table)
        return unless union_values?

        union_nodes      = apply_union_ordering(build_union_nodes!)
        table_name       = Arel::Nodes::SqlLiteral.new(unionized_name)
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
        union_values.each_with_index.inject(nil) do |union_node, (relation_node, index)|
          next resolve_relation_node(relation_node) if union_node.nil?

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

        # Sanitation check / resolver (ActiveRecord::Relation#preprocess_order_args)
        preprocess_order_args(union_ordering_values)
        union_ordering_values.uniq!
        Arel::Nodes::InfixOperation.new("ORDER BY", union_nodes, union_ordering_values)
      end

      private

      def unionize_error_or_warn!(raise_error = true)
        if raise_error && union_values.size <= 1
          raise ArgumentError, "You are required to provide 2 or more unions to join!"
        elsif !raise_error && union_values.size <= 1
          warn("Warning: You are required to provide 2 or more unions to join.")
        end
      end

      def resolve_relation_node(relation_node)
        case relation_node
        when String
          Arel::Nodes::Grouping.new(Arel::Nodes::SqlLiteral.new(relation_node))
        else
          relation_node.arel
        end
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::Unionize)
