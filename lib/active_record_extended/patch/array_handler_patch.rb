# frozen_string_literal: true

require "active_record/relation/predicate_builder"
require "active_record/relation/predicate_builder/array_handler"

module ActiveRecordExtended
  module Patch
    module ArrayHandlerPatch
      def call(attribute, value)
        cache = ActiveRecord::Base.connection.schema_cache
        if cache.data_source_exists?(attribute.relation.name)
          column = cache.columns(attribute.relation.name).detect { |col| col.name.to_s == attribute.name.to_s }
          return attribute.eq(value) if column.try(:array)
        end

        super
      end
    end
  end
end

ActiveRecord::PredicateBuilder::ArrayHandler.prepend(ActiveRecordExtended::Patch::ArrayHandlerPatch)
