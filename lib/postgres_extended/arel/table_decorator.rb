module Arel
  class Table
    def any_of(conditions = [])
      return from if conditions.nil? || conditions.empty?
      queries = conditions.map do |condition_hash|
        condition_hash.map do |column, value|
          Arel::Nodes::Equality.new(self[column], Nodes.build_quoted(value))
        end.reduce(:and)
      end.reduce(:group_or)

      from.where(queries)
    end
  end
end
