# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module Json
      JSON_QUERY_METHODS = [
        :select_row_to_json,
        :json_build_object,
        :jsonb_build_object,
        :json_build_literal,
        :jsonb_build_literal,
      ].freeze

      class JsonChain
        include ::ActiveRecordExtended::Utilities::Support
        include ::ActiveRecordExtended::Utilities::OrderBy

        DEFAULT_ALIAS    = '"results"'
        TO_JSONB_OPTIONS = [:array_agg, :distinct, :to_jsonb].to_set.freeze
        ARRAY_OPTIONS    = [:array, true].freeze

        def initialize(scope)
          @scope = scope
        end

        def row_to_json!(**args, &block)
          options = json_object_options(args, except: [:values, :value])
          build_row_to_json(**options, &block)
        end

        def json_build_object!(*args)
          options = json_object_options(args, except: [:values, :cast_with, :order_by])
          build_json_object(Arel::Nodes::JsonBuildObject, **options)
        end

        def jsonb_build_object!(*args)
          options = json_object_options(args, except: [:values, :cast_with, :order_by])
          build_json_object(Arel::Nodes::JsonbBuildObject, **options)
        end

        def json_build_literal!(*args)
          options = json_object_options(args, only: [:values, :col_alias])
          build_json_literal(Arel::Nodes::JsonBuildObject, **options)
        end

        def jsonb_build_literal!(*args)
          options = json_object_options(args, only: [:values, :col_alias])
          build_json_literal(Arel::Nodes::JsonbBuildObject, **options)
        end

        private

        def build_json_literal(arel_klass, values:, col_alias: DEFAULT_ALIAS)
          json_values    = flatten_to_sql(values.to_a) { |value| literal_key(value) }
          col_alias      = double_quote(col_alias)
          json_build_obj = arel_klass.new(json_values)
          @scope.select(nested_alias_escape(json_build_obj, col_alias))
        end

        def build_json_object(arel_klass, from:, key: key_generator, value: nil, col_alias: DEFAULT_ALIAS)
          tbl_alias         = double_quote(key)
          col_alias         = double_quote(col_alias)
          col_key           = literal_key(key)
          col_value         = to_arel_sql(value.presence || tbl_alias)
          json_build_object = arel_klass.new(to_sql_array(col_key, col_value))

          unless /".+"/.match?(col_value)
            warn("`#{col_value}`: the `value` argument should contain a double quoted key reference for safety")
          end

          @scope.select(nested_alias_escape(json_build_object, col_alias)).from(nested_alias_escape(from, tbl_alias))
        end

        def build_row_to_json(from:, **options, &block)
          key         = options[:key]
          row_to_json = ::Arel::Nodes::RowToJson.new(double_quote(key))
          row_to_json = ::Arel::Nodes::ToJsonb.new(row_to_json) if options.dig(:cast_with, :to_jsonb)

          dummy_table = from_clause_constructor(from, key).select(row_to_json)
          dummy_table = dummy_table.instance_eval(&block) if block_given?
          return dummy_table if options[:col_alias].blank?

          query = wrap_row_to_json(dummy_table, options)
          @scope.select(query)
        end

        def wrap_row_to_json(dummy_table, options)
          cast_opts = options[:cast_with]
          col_alias = options[:col_alias]
          order_by  = options[:order_by]

          if cast_opts[:array_agg] || cast_opts[:distinct]
            wrap_with_agg_array(dummy_table, col_alias, order_by: order_by, distinct: cast_opts[:distinct])
          elsif cast_opts[:array]
            wrap_with_array(dummy_table, col_alias, order_by: order_by)
          else
            nested_alias_escape(dummy_table, col_alias)
          end
        end

        # TODO: [V2 release] Drop support for option :cast_as_array in favor of a more versatile :cast_with option
        def json_object_options(args, except: [], only: []) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
          options   = {}
          lean_opts = lambda do |key, &block|
            if only.present?
              options[key] ||= block.call if only.include?(key)
            elsif !except.include?(key)
              options[key] ||= block.call
            end
          end

          flatten_safely(args) do |arg|
            next if arg.nil?

            if arg.is_a?(Hash)
              lean_opts.call(:key)       { arg.delete(:key) || key_generator }
              lean_opts.call(:value)     { arg.delete(:value).presence }
              lean_opts.call(:col_alias) { arg.delete(:as) }
              lean_opts.call(:order_by)  { order_by_expression(arg.delete(:order_by)) }
              lean_opts.call(:from)      { arg.delete(:from).tap { |from_clause| pipe_cte_with!(from_clause) } }
              lean_opts.call(:cast_with) { casting_options(arg.delete(:cast_with) || arg.delete(:cast_as_array)) }
            end

            unless except.include?(:values)
              options[:values] ||= []
              options[:values] << (arg.respond_to?(:to_a) ? arg.to_a : arg)
            end
          end

          options.tap(&:compact!)
        end

        def casting_options(cast_with)
          return {} if cast_with.blank?

          skip_convert = [Symbol, TrueClass, FalseClass]
          Array(cast_with).compact.each_with_object({}) do |arg, options|
            arg                  = arg.to_sym unless skip_convert.include?(arg.class)
            options[:to_jsonb]  |= TO_JSONB_OPTIONS.include?(arg)
            options[:array]     |= ARRAY_OPTIONS.include?(arg)
            options[:array_agg] |= arg == :array_agg
            options[:distinct]  |= arg == :distinct
          end
        end
      end

      # Appends a select statement that contains a subquery that is converted to a json response
      #
      # Arguments:
      #   - from: [String, Arel, or ActiveRecord::Relation] A subquery that can be nested into a ROW_TO_JSON clause
      #
      # Options:
      #   - as: [Symbol or String] (default="results"): What the column will be aliased to
      #
      #   - key: [Symbol or String] (default=[random letter]) What the row clause will be set as.
      #         - This is useful if you would like to add additional mid-level clauses (see mid-level scope example)
      #
      #   - cast_as_array [boolean] (default=false): Determines if the query should be nested inside an Array() function
      #     * Will be deprecated in V2.0 in favor of `cast_with` argument
      #
      #   - cast_with [Symbol or Array of symbols]: Actions to transform your query
      #     * :to_jsonb
      #     * :array
      #     * :array_agg (including just :array with this option will favor :array_agg)
      #     * :distinct  (auto applies :array_agg & :to_jsonb)
      #
      #   - order_by [Symbol or hash]: Applies an ordering operation (similar to ActiveRecord #order)
      #     - NOTE: this option will be ignored if you need to order a DISTINCT Aggregated Array,
      #             since postgres will thrown an error.
      #
      #
      #
      # Examples:
      #   subquery = Group.select(:name, :category_id).where("user_id = users.id")
      #   User.select(:name, email).select_row_to_json(subquery, as: :users_groups, cast_as_array: true)
      #     #=> [<#User name:.., email:.., users_groups: [{ name: .., category_id: .. }, ..]]
      #
      #  - Adding mid-level scopes:
      #
      #   subquery = Group.select(:name, :category_id)
      #   User.select_row_to_json(subquery, key: :group, cast_as_array: true) do |scope|
      #     scope.where(group: { name: "Nerd Core" })
      #   end
      #    #=>  ```sql
      #       SELECT ARRAY(
      #             SELECT ROW_TO_JSON("group")
      #             FROM(SELECT name, category_id FROM groups) AS group
      #             WHERE group.name = 'Nerd Core'
      #       )
      #    ```
      #
      #
      # - Array of JSONB objects
      #
      #   subquery = Group.select(:name, :category_id)
      #   User.select_row_to_json(subquery, key: :group, cast_with: [:array, :to_jsonb]) do |scope|
      #     scope.where(group: { name: "Nerd Core" })
      #   end
      #   #=>  ```sql
      #       SELECT ARRAY(
      #             SELECT TO_JSONB(ROW_TO_JSON("group"))
      #             FROM(SELECT name, category_id FROM groups) AS group
      #             WHERE group.name = 'Nerd Core'
      #       )
      #   ```
      #
      # - Distinct Aggregated Array
      #
      #   subquery = Group.select(:name, :category_id)
      #   User.select_row_to_json(subquery, key: :group, cast_with: [:array_agg, :distinct]) do |scope|
      #     scope.where(group: { name: "Nerd Core" })
      #   end
      #   #=>  ```sql
      #      SELECT ARRAY_AGG(DISTINCT (
      #            SELECT TO_JSONB(ROW_TO_JSON("group"))
      #            FROM(SELECT name, category_id FROM groups) AS group
      #            WHERE group.name = 'Nerd Core'
      #      ))
      #   ```
      #
      # - Ordering a Non-aggregated Array
      #
      #  subquery = Group.select(:name, :category_id)
      #  User.select_row_to_json(subquery, key: :group, cast_with: :array, order_by: { group: { name: :desc } })
      #  #=>  ```sql
      #     SELECT ARRAY(
      #           SELECT ROW_TO_JSON("group")
      #           FROM(SELECT name, category_id FROM groups) AS group
      #           ORDER BY group.name DESC
      #     )
      #  ```
      #
      # - Ordering an Aggregated Array
      #
      #  Subquery = Group.select(:name, :category_id)
      #  User
      #   .joins(:people_groups)
      #  .select_row_to_json(
      #     subquery,
      #     key: :group,
      #     cast_with: :array_agg,
      #     order_by: { people_groups: :category_id }
      #   )
      #   #=>  ```sql
      #     SELECT ARRAY_AGG((
      #           SELECT ROW_TO_JSON("group")
      #           FROM(SELECT name, category_id FROM groups) AS group
      #           ORDER BY group.name DESC
      #     ) ORDER BY people_groups.category_id ASC)
      #   ```
      #
      def select_row_to_json(from = nil, **options, &block)
        from.is_a?(Hash) ? options.merge!(from) : options.reverse_merge!(from: from)
        options.compact!
        raise ArgumentError, "Required to provide a non-nilled from clause" unless options.key?(:from)
        JsonChain.new(spawn).row_to_json!(**options, &block)
      end

      # Creates a json response object that will convert all subquery results into a json compatible response
      #
      # Arguments:
      #   key: [Symbol or String]: What should this response return as
      #   from: [String, Arel, or ActiveRecord::Relation] : A subquery that can be nested into the top-level from clause
      #
      # Options:
      #   - as: [Symbol or String] (default="results"): What the column will be aliased to
      #
      #
      #   - value: [Symbol or String] (defaults=[key]): How the response should handel the json value return
      #
      # Example:
      #
      #   - Generic example:
      #
      #   subquery = Group.select(:name, :category_id).where("user_id = users.id")
      #   User.select(:name, email).select_row_to_json(subquery, as: :users_groups, cast_as_array: true)
      #     #=> [<#User name:.., email:.., users_groups: [{ name: .., category_id: .. }, ..]]
      #
      #  - Setting a custom value:
      #
      #   Before:
      #       subquery = User.select(:name).where(id: 100..110).group(:name)
      #       User.build_json_object(:gang_members, subquery).take.results["gang_members"] #=> nil
      #
      #   After:
      #    User.build_json_object(:gang_members, subquery, value: "COALESCE(array_agg(\"gang_members\"), 'BANG!')")
      #        .take
      #        .results["gang_members"] #=> "BANG!"
      #
      def json_build_object(key, from, **options)
        options[:key]  = key
        options[:from] = from
        JsonChain.new(spawn).json_build_object!(options)
      end

      def jsonb_build_object(key, from, **options)
        options[:key]  = key
        options[:from] = from
        JsonChain.new(spawn).jsonb_build_object!(options)
      end

      # Appends a hash literal to the calling relations response
      #
      # Arguments: Requires an Array or Hash set of values
      #
      # Options:
      #
      #  - as: [Symbol or String] (default="results"): What the column will be aliased to
      #
      # Example:
      #  - Supplying inputs as a Hash
      #      query = User.json_build_literal(number: 1, last_name: "json", pi: 3.14)
      #      query.take.results #=> { "number" => 1, "last_name" => "json", "pi" => 3.14 }
      #
      #  - Supplying inputs as an Array
      #
      #      query = User.json_build_literal(:number, 1, :last_name, "json", :pi, 3.14)
      #      query.take.results #=> { "number" => 1, "last_name" => "json", "pi" => 3.14 }
      #

      def json_build_literal(*args)
        JsonChain.new(spawn).json_build_literal!(args)
      end

      def jsonb_build_literal(*args)
        JsonChain.new(spawn).jsonb_build_literal!(args)
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::Json)
