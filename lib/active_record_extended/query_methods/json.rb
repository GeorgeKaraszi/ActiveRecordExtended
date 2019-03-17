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
        include ::ActiveRecordExtended::Utilities
        DEFAULT_ALIAS = '"results"'

        def initialize(scope)
          @scope = scope
        end

        def row_to_json!(**args, &block)
          build_row_to_json(
            args.delete(:from).tap(&method(:pipe_cte_with!)),
            args.delete(:key) || key_generator,
            args.delete(:as),
            !(!args.delete(:cast_as_array)),
            &block
          )
        end

        def json_build_object!(*args)
          options = json_object_options(args).except!(:values)
          build_json_object(Arel::Nodes::JsonBuildObject, **options)
        end

        def jsonb_build_object!(*args)
          options = json_object_options(args).except!(:values)
          build_json_object(Arel::Nodes::JsonbBuildObject, **options)
        end

        def json_build_literal!(*args)
          options = json_object_options(args).slice(:values, :col_alias)
          build_json_literal(Arel::Nodes::JsonBuildObject, **options)
        end

        def jsonb_build_literal!(*args)
          options = json_object_options(args).slice(:values, :col_alias)
          build_json_literal(Arel::Nodes::JsonbBuildObject, **options)
        end

        private

        def build_json_literal(arel_klass, values:, col_alias: DEFAULT_ALIAS)
          json_values    = flatten_to_sql(values.to_a, &method(:literal_key))
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

          # TODO: Change this to #match?(..) when we drop Rails 5.0 or Ruby 2.4 support
          unless col_value.index(/".+"/)
            warn("`#{col_value}`: the `value` argument should contain a double quoted key reference for safety")
          end

          @scope.select(nested_alias_escape(json_build_object, col_alias)).from(nested_alias_escape(from, tbl_alias))
        end

        def build_row_to_json(from, top_lvl_key, col_alias, cast_to_array)
          row_to_json = Arel::Nodes::RowToJson.new(double_quote(top_lvl_key))
          dummy_table = from_clause_constructor(from, top_lvl_key).select(row_to_json)
          dummy_table = yield dummy_table if block_given?

          if col_alias.blank?
            dummy_table
          elsif cast_to_array
            @scope.select(wrap_with_array(dummy_table, col_alias))
          else
            @scope.select(nested_alias_escape(dummy_table, col_alias))
          end
        end

        def json_object_options(*args) # rubocop:disable Metrics/AbcSize
          flatten_safely(args).each_with_object(values: []) do |arg, options|
            next if arg.nil?

            if arg.is_a?(Hash)
              options[:key]           ||= arg.delete(:key)
              options[:value]         ||= arg.delete(:value).presence
              options[:col_alias]     ||= arg.delete(:as)
              options[:cast_to_array] ||= arg.delete(:cast_as_array)
              options[:from]          ||= arg.delete(:from).tap(&method(:pipe_cte_with!))
            end

            options[:values] << (arg.respond_to?(:to_a) ? arg.to_a : arg)
          end.compact
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
      #
      # Example:
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
      #

      def select_row_to_json(from = nil, **options, &block)
        from.is_a?(Hash) ? options.merge!(from) : options.reverse_merge!(from: from)
        options.compact!
        raise ArgumentError, "Required to provide a [from:] options key" unless options.key?(:from)
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
      #
      # - Adding mid-level scopes
      #
      #   subquery = Group.select(:name, :category_id)
      #   User.select_row_to_json(subquery, key: :group, cast_as_array: true) do |scope|
      #     scope.where(group: { name: "Nerd Core" })
      #   end  #=>  ```sql
      #       SELECT ARRAY(
      #             SELECT ROW_TO_JSON("group")
      #             FROM(SELECT name, category_id FROM groups) AS group
      #             WHERE group.name = 'Nerd Core'
      #       )
      #     ```
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
      #      query.take.results #=> { "number" => 1, "last_name" => "john", "pi" => 3.14 }
      #
      #  - Supplying inputs as an Array
      #
      #      query = User.json_build_literal(:number, 1, :last_name, "json", :pi, 3.14)
      #      query.take.results #=> { "number" => 1, "last_name" => "john", "pi" => 3.14 }
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
