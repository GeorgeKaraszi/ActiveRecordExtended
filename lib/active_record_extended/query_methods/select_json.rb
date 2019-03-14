# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module SelectJson
      JSON_QUERY_METHODS = [:select_row_to_json].freeze

      class SelectJsonChain
        include ::ActiveRecordExtended::Utilities

        def initialize(scope)
          @scope = scope
        end

        def row_to_json!(**options)
          cast_to_array = !(!options.delete(:cast_as_array))
          top_lvl_key   = options.delete(:key) || key_generator
          col_alias     = options.delete(:as)
          dummy_scope   = from_clause_constructor(options.delete(:from), top_lvl_key)
          dummy_scope   = yield dummy_scope if block_given?
          build_row_to_json(dummy_scope, col_alias, cast_to_array, top_lvl_key)
        end

        private

        def build_row_to_json(from, col_alias, cast_to_array, top_lvl_key)
          row_to_json = Arel::Nodes::RowToJson.new(double_quote(top_lvl_key))
          dummy_table = from.select(row_to_json)

          if col_alias.blank?
            dummy_table
          elsif cast_to_array
            @scope.select(wrap_with_array(dummy_table, col_alias))
          else
            @scope.select(nested_alias_escape(dummy_table, col_alias))
          end
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
          end
        end
      end

      def select_row_to_json(**options, &block)
        raise ArgumentError, "Required to provide a [from:] options key" unless options.key?(:from)
        SelectJsonChain.new(spawn).row_to_json!(**options, &block)
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::SelectJson)
