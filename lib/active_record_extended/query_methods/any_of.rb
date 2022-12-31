# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module AnyOf
      def any_of(*queries)
        queries = hash_map_queries(queries)
        build_query(queries) do |arel_query|
          @scope.where(arel_query)
        end
      end

      def none_of(*queries)
        queries = hash_map_queries(queries)
        build_query(queries) do |arel_query|
          @scope.where.not(arel_query)
        end
      end

      private

      def hash_map_queries(queries)
        if queries.size == 1 && queries.first.is_a?(Hash)
          queries.first.each_pair.map { |attr, predicate| { attr => predicate } }
        else
          queries
        end
      end

      def build_query(queries)
        query_map = construct_query_mappings(queries)
        query     = yield(query_map[:arel_query])
        query
          .joins(query_map[:joins].to_a)
          .includes(query_map[:includes].to_a)
          .references(query_map[:references].to_a)
      end

      def construct_query_mappings(queries) # rubocop:disable Metrics/AbcSize
        { joins: Set.new, references: Set.new, includes: Set.new, arel_query: nil, binds: [] }.tap do |query_map|
          query_map[:arel_query] = queries.map do |raw_query|
            query = generate_where_clause(raw_query)
            query_map[:joins]      << translate_reference(query.joins_values)      if query.joins_values.any?
            query_map[:includes]   << translate_reference(query.includes_values)   if query.includes_values.any?
            query_map[:references] << translate_reference(query.references_values) if query.references_values.any?
            query.arel.constraints.reduce(:and)
          end.reduce(:or)
        end
      end

      def translate_reference(reference)
        reference.filter_map { |ref| ref.try(:to_sql) || ref }
      end

      def generate_where_clause(query)
        case query
        when String, Hash
          @scope.unscoped.where(query)
        when Array
          @scope.unscoped.where(*query)
        else
          query
        end
      end
    end
  end
end

ActiveRecord::QueryMethods::WhereChain.prepend(ActiveRecordExtended::QueryMethods::AnyOf)
