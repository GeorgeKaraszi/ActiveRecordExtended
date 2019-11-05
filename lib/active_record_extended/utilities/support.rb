# frozen_string_literal: true

module ActiveRecordExtended
  module Utilities
    module Support
      A_TO_Z_KEYS = ("a".."z").to_a.freeze

      # We need to ensure we can flatten nested ActiveRecord::Relations
      # that might have been nested due to the (splat)*args parameters
      #
      # Note: calling `Array.flatten[!]/1` will actually remove all AR relations from the array.
      #
      def flatten_to_sql(*values)
        flatten_safely(values) do |value|
          value = yield value if block_given?
          to_arel_sql(value)
        end
      end
      alias to_sql_array flatten_to_sql

      def flatten_safely(values, &block)
        unless values.is_a?(Array)
          values = yield values if block_given?
          return [values]
        end

        values.map { |value| flatten_safely(value, &block) }.reduce(:+)
      end

      # Applies aliases to the given query
      # Ex: `SELECT * FROM users` => `(SELECT * FROM users) AS "members"`
      def nested_alias_escape(query, alias_name)
        sql_query = generate_grouping(query)
        Arel::Nodes::As.new(sql_query, to_arel_sql(double_quote(alias_name)))
      end

      # Wraps subquery into an Aliased ARRAY
      # Ex: `SELECT * FROM users` => (ARRAY(SELECT * FROM users)) AS "members"
      def wrap_with_array(arel_or_rel_query, alias_name, order_by: false)
        if order_by && arel_or_rel_query.is_a?(ActiveRecord::Relation)
          arel_or_rel_query = arel_or_rel_query.order(order_by)
        end

        query = Arel::Nodes::Array.new(to_sql_array(arel_or_rel_query))
        nested_alias_escape(query, alias_name)
      end

      # Wraps query into an aggregated array
      # EX: `(ARRAY_AGG((SELECT * FROM users)) AS "members"`
      #     `(ARRAY_AGG(DISTINCT (SELECT * FROM users)) AS "members"`
      #     `SELECT ARRAY_AGG((id)) AS "ids" FROM users`
      #     `SELECT ARRAY_AGG(DISTINCT (id)) AS "ids" FROM users`
      def wrap_with_agg_array(arel_or_rel_query, alias_name, order_by: false, distinct: false)
        distinct       = !(!distinct)
        order_exp      = distinct ? nil : order_by # Can't order a distinct agg
        query          = group_when_needed(arel_or_rel_query)
        query          =
          Arel::Nodes::AggregateFunctionName
          .new("ARRAY_AGG", to_sql_array(query), distinct)
          .order_by(order_exp)

        nested_alias_escape(query, alias_name)
      end

      # Will attempt to digest and resolve the from clause
      #
      # If the from clause is a String, it will check to see if a table reference key has been assigned.
      #   - If one cannot be detected, one will be appended.
      #   - Rails does not allow assigning table references using the `.from/2` method, when its a string / sym type.
      #
      # If the from clause is an AR relation; it will duplicate the object.
      #   - Ensures any memorizers are reset (ex: `.to_sql` sets a memorizer on the instance)
      #   - Key's can be assigned using the `.from/2` method.
      #
      def from_clause_constructor(from, reference_key)
        case from
        when /\s.?#{reference_key}.?$/ # The from clause is a string and has the tbl reference key
          @scope.unscoped.from(from)
        when String, Symbol
          @scope.unscoped.from("#{from} #{reference_key}")
        else
          replicate_klass = from.respond_to?(:unscoped) ? from.unscoped : @scope.unscoped
          replicate_klass.from(from.dup, reference_key)
        end.unscope(:where)
      end

      # Will carry defined CTE tables from the nested sub-query and gradually pushes it up to the parents query stack
      # I.E: It pushes `WITH [:cte_name:] AS(...), ..` to the top of the query structure tree
      #
      # SPECIAL GOTCHA NOTE: (if duplicate keys are found) This will favor the parents query `with's` over nested ones!
      def pipe_cte_with!(subquery)
        return self unless subquery.try(:with_values?)

        cte_ary              = flatten_safely(subquery.with_values)
        subquery.with_values = nil # Remove nested queries with values

        # Add subquery's CTE's to the parents query stack. (READ THE SPECIAL NOTE ABOVE!)
        if @scope.with_values?
          # combine top-level and lower level queries `.with` values into 1 structure
          with_hash = cte_ary.each_with_object(@scope.with_values.first) do |from_cte, hash|
            hash.reverse_merge!(from_cte)
          end

          @scope.with_values = [with_hash]
        else
          # Top level has no with values
          @scope.with!(*cte_ary)
        end

        self
      end

      # Ensures the given value is properly double quoted.
      # This also ensures we don't have conflicts with reversed keywords.
      #
      # IE: `user` is a reserved keyword in PG. But `"user"` is allowed and works the same
      #     when used as an column/tbl alias.
      def double_quote(value)
        return if value.nil?

        case value.to_s
          # Ignore keys that contain double quotes or a Arel.star (*)[all columns]
          # or if a table has already been explicitly declared (ex: users.id)
        when "*", /((^".+"$)|(^[[:alpha:]]+\.[[:alnum:]]+))/
          value
        else
          PG::Connection.quote_ident(value.to_s)
        end
      end

      # Ensures the key is properly single quoted and treated as a actual PG key reference.
      def literal_key(key)
        case key
        when TrueClass  then "'t'"
        when FalseClass then "'f'"
        when Numeric    then key
        else
          key = key.to_s
          key.start_with?("'") && key.end_with?("'") ? key : "'#{key}'"
        end
      end

      # Converts a potential subquery into a compatible Arel SQL node.
      #
      # Note:
      # We convert relations to SQL to maintain compatibility with Rails 5.[0/1].
      # Only Rails 5.2+ maintains bound attributes in Arel, so its better to be safe then sorry.
      # When we drop support for Rails 5.[0/1], we then can then drop the '.to_sql' conversation

      def to_arel_sql(value)
        case value
        when Arel::Node, Arel::Nodes::SqlLiteral, nil
          value
        when ActiveRecord::Relation
          Arel.sql(value.spawn.to_sql)
        else
          Arel.sql(value.respond_to?(:to_sql) ? value.to_sql : value.to_s)
        end
      end

      def group_when_needed(arel_or_rel_query)
        return arel_or_rel_query unless needs_to_be_grouped?(arel_or_rel_query)
        generate_grouping(arel_or_rel_query)
      end

      def needs_to_be_grouped?(query)
        query.respond_to?(:to_sql) || (query.is_a?(String) && /^SELECT.+/i.match?(query))
      end

      def generate_grouping(expr)
        ::Arel::Nodes::Grouping.new(to_arel_sql(expr))
      end

      def generate_named_function(function_name, *args)
        args.map! { |arg| to_arel_sql(arg) }
        function_name = function_name.to_s.upcase
        ::Arel::Nodes::NamedFunction.new(to_arel_sql(function_name), args)
      end

      def key_generator
        A_TO_Z_KEYS.sample
      end
    end
  end
end
