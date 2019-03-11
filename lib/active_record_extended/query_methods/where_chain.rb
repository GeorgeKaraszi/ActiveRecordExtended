# frozen_string_literal: true

module ActiveRecordExtended
  module WhereChain
    # Finds Records that have an array column that contain any a set of values
    # User.where.overlap(tags: [1,2])
    #   # SELECT * FROM users WHERE tags && {1,2}
    def overlap(opts, *rest)
      substitute_comparisons(opts, rest, Arel::Nodes::Overlap, "overlap")
    end

    # Finds Records that contain an element in an array column
    # User.where.any(tags: 3)
    #   # SELECT user.* FROM user WHERE 3 = ANY(user.tags)
    def any(opts, *rest)
      equality_to_function("ANY", opts, rest)
    end

    # Finds Records that contain a single matchable array element
    # User.where.all(tags: 3)
    #   # SELECT user.* FROM user WHERE 3 = ALL(user.tags)
    def all(opts, *rest)
      equality_to_function("ALL", opts, rest)
    end

    # Finds Records that contains a nested set elements
    #
    # Array Column Type:
    #   User.where.contains(tags: [1, 3])
    #   # SELECT user.* FROM user WHERE user.tags @> {1,3}
    #
    # HStore Column Type:
    #   User.where.contains(data: { nickname: 'chainer' })
    #   # SELECT user.* FROM user WHERE user.data @> 'nickname' => 'chainer'
    #
    # JSONB Column Type:
    #   User.where.contains(data: { nickname: 'chainer' })
    #   # SELECT user.* FROM user WHERE user.data @> {'nickname': 'chainer'}
    #
    # This can also be used along side joined tables
    #
    # JSONB Column Type Example:
    #   Tag.joins(:user).where.contains(user: { data: { nickname: 'chainer' } })
    #   # SELECT tags.* FROM tags INNER JOIN user on user.id = tags.user_id WHERE user.data @> { nickname: 'chainer' }
    #
    def contains(opts, *rest)
      build_where_chain(opts, rest) do |arel|
        case arel
        when Arel::Nodes::In, Arel::Nodes::Equality
          column = left_column(arel) || column_from_association(arel)

          if [:hstore, :jsonb].include?(column.type)
            Arel::Nodes::ContainsHStore.new(arel.left, arel.right)
          elsif column.try(:array)
            Arel::Nodes::ContainsArray.new(arel.left, arel.right)
          else
            raise ArgumentError, "Invalid argument for .where.contains(), got #{arel.class}"
          end
        else
          raise ArgumentError, "Invalid argument for .where.contains(), got #{arel.class}"
        end
      end
    end

    private

    def matchable_column?(col, arel)
      col.name == arel.left.name.to_s || col.name == arel.left.relation.name.to_s
    end

    def column_from_association(arel)
      assoc = assoc_from_related_table(arel)
      assoc.klass.columns.detect { |col| matchable_column?(col, arel) } if assoc
    end

    def assoc_from_related_table(arel)
      @scope.klass.reflect_on_association(arel.left.relation.name.to_sym) ||
        @scope.klass.reflect_on_association(arel.left.relation.name.singularize.to_sym)
    end

    def left_column(arel)
      @scope.klass.columns_hash[arel.left.name] || @scope.klass.columns_hash[arel.left.relation.name]
    end

    def equality_to_function(function_name, opts, rest)
      build_where_chain(opts, rest) do |arel|
        case arel
        when Arel::Nodes::Equality
          Arel::Nodes::Equality.new(arel.right, Arel::Nodes::NamedFunction.new(function_name, [arel.left]))
        else
          raise ArgumentError, "Invalid argument for .where.#{function_name.downcase}(), got #{arel.class}"
        end
      end
    end

    def substitute_comparisons(opts, rest, arel_node_class, method)
      build_where_chain(opts, rest) do |arel|
        case arel
        when Arel::Nodes::In, Arel::Nodes::Equality
          arel_node_class.new(arel.left, arel.right)
        else
          raise ArgumentError, "Invalid argument for .where.#{method}(), got #{arel.class}"
        end
      end
    end
  end
end

module ActiveRecord
  module QueryMethods
    class WhereChain
      prepend ActiveRecordExtended::WhereChain

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
