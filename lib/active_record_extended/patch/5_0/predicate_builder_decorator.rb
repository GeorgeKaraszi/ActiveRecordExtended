# frozen_string_literal: true

# Stripped from Rails 5.1.x
# This patch is used so that when querying with hash elements that do not belong to an association,
# but instead a data attribute. It returns the corrected attribute binds back to the query builder.
#
# Without joins
# Before:
#   User.where.contains(data: { nickname: "george" })
#     #=> "SELECT \"people\".* FROM \"people\" WHERE (\"data\".\"nickname\" @> 'george')"
#
# After:
#  User.where.contains(data: { nickname: "george" })
#   #=> "SELECT \"people\".* FROM \"people\" WHERE (\"people\".\"data\" @> '\"nickname\"=>\"george\"')"
#
# With Joins
# Before:
#   Tag.joins(:user).where.contains(people: { data: { nickname: "george" } })
#   #=> NoMethodError: undefined method `type' for nil:NilClass
#
# After:
#  Tag.joins(:user).where.contains(people: { data: { nickname: "george" } })
#  #=> "SELECT \"tags\".* FROM \"tags\" INNER JOIN \"people\" ON \"people\".\"id\" = \"tags\".\"person_id\"
#         WHERE (\"people\".\"data\" @> '\"nickname\"=>\"george\"')"
#
module ActiveRecord
  class TableMetadata
    def has_column?(column_name) # rubocop:disable Naming/PredicateName
      klass&.columns_hash&.key?(column_name.to_s)
    end
  end

  class PredicateBuilder
    def create_binds_for_hash(attributes) # rubocop:disable Metrics/PerceivedComplexity, Metrics/AbcSize
      result = attributes.dup
      binds = []

      attributes.each do |column_name, value| # rubocop:disable Metrics/BlockLength
        if value.is_a?(Hash) && !table.has_column?(column_name)
          attrs, bvs = associated_predicate_builder(column_name).create_binds_for_hash(value)
          result[column_name] = attrs
          binds += bvs
          next
        elsif value.is_a?(Relation)
          binds += value.bound_attributes
        elsif value.is_a?(Range) && !table.type(column_name).respond_to?(:subtype)
          first = value.begin
          last = value.end
          unless first.respond_to?(:infinite?) && first.infinite?
            binds << build_bind_param(column_name, first)
            first = Arel::Nodes::BindParam.new
          end
          unless last.respond_to?(:infinite?) && last.infinite?
            binds << build_bind_param(column_name, last)
            last = Arel::Nodes::BindParam.new
          end

          result[column_name] = RangeHandler::RangeWithBinds.new(first, last, value.exclude_end?)
        elsif can_be_bound?(column_name, value)
          result[column_name] = Arel::Nodes::BindParam.new
          binds << build_bind_param(column_name, value)
        end

        # Find the foreign key when using queries such as:
        # Post.where(author: author)
        #
        # For polymorphic relationships, find the foreign key and type:
        # PriceEstimate.where(estimate_of: treasure)
        if table.associated_with?(column_name)
          result[column_name] = AssociationQueryHandler.value_for(table, column_name, value)
        end
      end

      [result, binds]
    end

    def can_be_bound?(column_name, value)
      return if table.associated_with?(column_name)
      case value
      when Array, Range
        table.type(column_name).respond_to?(:subtype)
      else
        !value.nil? && handler_for(value).is_a?(BasicObjectHandler)
      end
    end
  end
end
