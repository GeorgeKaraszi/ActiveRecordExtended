# frozen_string_literal: true

require "ar_outer_joins"

module ActiveRecordExtended
  module QueryMethods
    module Either
      XOR_FIELD_SQL  = "(CASE WHEN %<t1>s.%<c1>s IS NULL THEN %<t2>s.%<c2>s ELSE %<t1>s.%<c1>s END) "
      XOR_FIELD_KEYS = [:t1, :c1, :t2, :c2].freeze

      def either_join(initial_association, fallback_association)
        associations        = [initial_association, fallback_association]
        association_options = xor_field_options_for_associations(associations)
        condition__query    = xor_field_sql(association_options) + "= #{table_name}.#{primary_key}"
        outer_joins(associations).where(Arel.sql(condition__query))
      end
      alias either_joins either_join

      def either_order(direction, **associations_and_columns)
        reflected_columns = map_columns_to_tables(associations_and_columns)
        conditional_query = xor_field_sql(reflected_columns) + sort_order_sql(direction)
        outer_joins(associations_and_columns.keys).order(Arel.sql(conditional_query))
      end
      alias either_orders either_order

      private

      def xor_field_sql(options)
        XOR_FIELD_SQL % Hash[xor_field_options(options)]
      end

      def sort_order_sql(dir)
        %w[asc desc].include?(dir.to_s) ? dir.to_s : "asc"
      end

      def xor_field_options(options)
        str_args = options.flatten.take(XOR_FIELD_KEYS.size).map(&:to_s)
        Hash[XOR_FIELD_KEYS.zip(str_args)]
      end

      def map_columns_to_tables(associations_and_columns)
        if associations_and_columns.respond_to?(:transform_keys)
          associations_and_columns.transform_keys { |assc| reflect_on_association(assc).table_name }
        else
          associations_and_columns.each_with_object({}) do |(assc, value), key_table|
            reflect_table            = reflect_on_association(assc).table_name
            key_table[reflect_table] = value
          end
        end
      end

      def xor_field_options_for_associations(associations)
        associations.each_with_object({}) do |association_name, options|
          reflection = reflect_on_association(association_name)
          options[reflection.table_name] = reflection.foreign_key
        end
      end
    end
  end
end

ActiveRecord::Base.extend(ActiveRecordExtended::QueryMethods::Either)
