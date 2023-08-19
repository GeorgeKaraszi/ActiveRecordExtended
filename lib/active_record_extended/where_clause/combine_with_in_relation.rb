# frozen_string_literal: true

module ActiveRecordExtended
  module WhereClause
    class CombineWithInRelation < ActiveRecord::Relation::WhereClause
      def ast
        predicates = predicates_with_wrapped_sql_literals
        return predicates.first if predicates.one?

        equality_predicats, other_predicats = split_predicates(predicates)

        return Arel::Nodes::And.new(predicates) if equality_predicats.empty?

        ast_for_equality_predicates(equality_predicats, other_predicats)
      end

      private

      def ast_for_equality_predicates(equality_predicats, other_predicats)
        grouped_equality_predicates = equality_predicats.group_by { |equality_predicat| equality_predicat.right.name }
        if grouped_equality_predicates.one? && other_predicats.empty?
          values = predicate_values(predicates)
          attribute = predicates.first.left
          Arel::Nodes::HomogeneousIn.new(values, attribute, :in)
        else
          combined_predicates = other_predicats + equality_predicates(grouped_equality_predicates)
          Arel::Nodes::And.new(combined_predicates)
        end
      end

      def predicate_values(predicates)
        predicates.map do |predicate|
          value = predicate.right.value
          if value.instance_of?(Hash)
            value.map { |key, hash_values| hash_values.map { |hash_value| hash_value[key] } }
          else
            value
          end
        end.flatten
      end

      def split_predicates(predicates)
        predicates.each_with_object([[], []]) do |predicate, acc|
          if predicate.instance_of?(Arel::Nodes::Equality)
            [acc.first.push(predicate), acc.last]
          else
            [acc.first, acc.last.push(predicate)]
          end
        end
      end

      def equality_predicates(grouped_equality_predicates)
        grouped_equality_predicates.values.map do |predicates_by_name|
          if predicates_by_name.one?
            predicates_by_name.first
          else
            values = predicate_values(predicates_by_name)
            attribute = predicates_by_name.first.left
            Arel::Nodes::HomogeneousIn.new(values, attribute, :in)
          end
        end
      end
    end
  end
end
