# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module Select
      class SelectHelper
        include ::ActiveRecordExtended::Utilities::Support
        include ::ActiveRecordExtended::Utilities::OrderBy

        AGGREGATE_ONE_LINERS = /^(exists|sum|max|min|avg|count|jsonb?_agg|(bit|bool)_(and|or)|xmlagg|array_agg)$/.freeze

        def initialize(scope)
          @scope = scope
        end

        def build_foster_select(*args)
          flatten_safely(args).each do |select_arg|
            case select_arg
            when String, Symbol
              select!(select_arg)
            when Hash
              select_arg.each_pair do |alias_name, options_or_column|
                case options_or_column
                when Array
                  process_array!(options_or_column, alias_name)
                when Hash
                  process_hash!(options_or_column, alias_name)
                else
                  select!(options_or_column, alias_name)
                end
              end
            end
          end
        end

        private

        # Assumes that the first element in the array is the source/target column.
        # Example
        # process_array_options!([:col_name], :my_alias_name)
        #    #=> SELECT ([:col_name:]) AS "my_alias_name", ...
        def process_array!(array_of_options, alias_name)
          options = array_of_options.detect { |opts| opts.is_a?(Hash) }
          query   = { __select_statement: array_of_options.first }
          query.merge!(options) unless options.nil?
          process_hash!(query, alias_name)
        end

        # Processes options that come in as Hash elements
        # Examples:
        # process_hash_options!({ memberships: :price, cast_with: :agg_array_distinct }, :past_purchases)
        #  #=> SELECT (ARRAY_AGG(DISTINCT members.price)) AS past_purchases, ...
        def process_hash!(hash_of_options, alias_name)
          enforced_options = {
            cast_with: hash_of_options.delete(:cast_with),
            order_by:  hash_of_options.delete(:order_by),
            distinct:  !(!hash_of_options.delete(:distinct)),
          }
          query_statement = hash_to_dot_notation(hash_of_options.delete(:__select_statement) || hash_of_options.first)
          select!(query_statement, alias_name, enforced_options)
        end

        # Turn a hash chain into a query statement:
        # Example: hash_to_dot_notation(table_name: :col_name) #=> "table_name.col_name"
        def hash_to_dot_notation(column)
          case column
          when Hash, Array
            column.to_a.flat_map { |col| hash_to_dot_notation(col) }.join(".")
          when String, Symbol
            /^([[:alpha:]]+)$/.match?(column.to_s) ? double_quote(column) : column
          else
            column
          end
        end

        # Add's select statement values to the current relation, select statement lists
        def select!(query, alias_name = nil, **options)
          pipe_cte_with!(query)
          @scope._select!(to_casted_query(query, alias_name, options))
        end

        # Wraps the query with the requested query method
        # Example:
        #   to_casted_query("memberships.cost", :total_revenue, :sum)
        #    #=> SELECT (SUM(memberships.cost)) AS total_revenue
        def to_casted_query(query, alias_name, **options)
          cast_with  = options.delete(:cast_with).to_s.downcase
          order_expr = order_by_expression(options.delete(:order_by))
          distinct   = cast_with.chomp!("_distinct") || options.delete(:distinct) # account for [:agg_name:]_distinct

          case cast_with
          when "array", "true"
            wrap_with_array(query, alias_name)
          when AGGREGATE_ONE_LINERS
            expr         = to_sql_array(query) { |value| group_when_needed(value) }
            casted_query = ::Arel::Nodes::AggregateFunctionName.new(cast_with, expr, distinct).order_by(order_expr)
            nested_alias_escape(casted_query, alias_name)
          else
            alias_name.presence ? nested_alias_escape(query, alias_name) : query
          end
        end
      end

      def foster_select(*args)
        raise ArgumentError, "Call `.forster_select' with at least one field" if args.empty?
        spawn._foster_select!(*args)
      end

      def _foster_select!(*args)
        SelectHelper.new(self).build_foster_select(*args)
        self
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::Select)
