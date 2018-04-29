# frozen_string_literal: true

require "active_record/relation/predicate_builder"
require "active_record/relation/predicate_builder/array_handler"

module PostgresExtended
  module ArrayHandlerDecorator
    def call(attribute, value)
      column =
        case attribute.try(:relation)
        when Arel::Nodes::TableAlias, NilClass
          nil
        else
          cache = ActiveRecord::Base.connection.schema_cache
          if cache.data_source_exists?(attribute.relation.name)
            cache.columns(attribute.relation.name).detect { |col| col.name.to_s == attribute.name.to_s }
          end
        end

      column.try(:array) ? attribute.eq(value) : super
    end
  end
end

ActiveRecord::PredicateBuilder::ArrayHandler.prepend(PostgresExtended::ArrayHandlerDecorator)
