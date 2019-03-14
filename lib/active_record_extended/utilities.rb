# frozen_string_literal: true

module ActiveRecordExtended
  module Utilities
    A_TO_Z_KEYS = ("a".."z").to_a.freeze

    # We need to ensure we can flatten nested ActiveRecord::Relations
    # that might have been nested due to the (splat)*args parameters
    #
    # Note: calling `Array.flatten[!]/1` will actually remove all AR relations from the array.
    #
    def flatten_to_sql(values)
      return [to_arel_sql(values)].compact unless values.is_a?(Array)
      values.inject([]) { |new_ary, value| new_ary + flatten_to_sql(value) }.compact
    end

    # Applies aliases to the given query
    # Ex: `SELECT * FROM users` => `(SELECT * FROM users) AS "members"`
    def nested_alias_escape(query, alias_name)
      sql_query = Arel::Nodes::Grouping.new(to_arel_sql(query))
      Arel::Nodes::As.new(sql_query, Arel.sql(double_quote(alias_name)))
    end

    # Wraps subquery into an Aliased ARRAY
    # Ex: `SELECT * FROM users` => (ARRAY(SELECT * FROM users)) AS "members"
    def wrap_with_array(arel_or_rel_query, alias_name)
      query = Arel::Nodes::NamedFunction.new("ARRAY", flatten_to_sql(arel_or_rel_query))
      nested_alias_escape(query, alias_name)
    end

    # Ensures the given value is properly double quoted.
    # This also ensures we don't have conflicts with reversed keywords.
    #
    # IE: `user` is a reserved keyword in PG. But `"user"` is allowed and works the same
    #     when used as an column/tbl alias.
    def double_quote(value)
      return if value.nil?

      case value.to_s
      when "*", /^".+"$/ # Ignore keys that contain double quotes or a Arel.star (*)[all columns]
        value
      else
        PG::Connection.quote_ident(value.to_s)
      end
    end

    # Converts a potential subquery into a compatible Arel SQL node.
    #
    # Note:
    # We convert relations to SQL to maintain compatibility with Rails 5.[0/1].
    # Only Rails 5.2+ maintains bound attributes in Arel, so its better to be safe then sorry.
    # When we drop support for Rails 5.[0/1], we then can then drop the '.to_sql' conversation

    def to_arel_sql(value)
      return                              if value.nil?
      return Arel.sql(value.spawn.to_sql) if value.is_a?(ActiveRecord::Relation)

      Arel.sql(value.respond_to?(:to_sql) ? value.to_sql : value.to_s)
    end

    def key_generator
      A_TO_Z_KEYS.sample
    end
  end
end
