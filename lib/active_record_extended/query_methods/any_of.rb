# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module AnyOf
      def any_of(*queries)
        queries = hash_map_queries(queries)
        @scope.where(build_or_queries(queries))
      end

      def none_of(*queries)
        queries = hash_map_queries(queries)
        @scope.where.not(build_or_queries(queries))
      end

      private

      def hash_map_queries(queries)
        if queries.count == 1 && queries.first.is_a?(Hash)
          queries.first.each_pair.map { |attr, predicate| Hash[attr, predicate] }
        else
          queries
        end
      end

      def build_quries(queries)
        where_queries = queries(queries)
      end

      def queries(queries)
       queries.map do |query|
         query = generate_where_clause(query)
         Arel::SelectManager
         i = q.arel
         con = q.arel.constraints
         c = q.arel.constraints.reduce(:and)
         q
       end.reduce(:group_or)
      end

      def generate_where_clause(query)
        case query
        when String, Hash
          @scope.where(query)
        when Array
          @scope.where(*query)
        else
          query
        end
      end
    end
  end
end

ActiveRecord::QueryMethods::WhereChain.prepend(ActiveRecordExtended::QueryMethods::AnyOf)
