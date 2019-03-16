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
            args.delete(:from),
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
              options[:from]          ||= arg.delete(:from)
            end

            options[:values] << (arg.respond_to?(:to_a) ? arg.to_a : arg)
          end.compact
        end
      end

      def select_row_to_json(from = nil, **options, &block)
        from.is_a?(Hash) ? options.merge!(from) : options.reverse_merge!(from: from)
        options.compact!
        raise ArgumentError, "Required to provide a [from:] options key" unless options.key?(:from)
        JsonChain.new(spawn).row_to_json!(**options, &block)
      end

      def json_build_object(key, **options)
        options[:key] ||= key
        JsonChain.new(spawn).json_build_object!(options)
      end

      def jsonb_build_object(key, **options)
        options[:key] ||= key
        JsonChain.new(spawn).jsonb_build_object!(options)
      end

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
