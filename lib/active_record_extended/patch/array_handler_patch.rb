# frozen_string_literal: true

require "active_record/relation/predicate_builder"
require "active_record/relation/predicate_builder/array_handler"

module ActiveRecordExtended
  module Patch
    module ArrayHandlerPatch
      def call(attribute, value)
        # Resolve the connection through the model that owns the Arel table,
        # rather than hardcoding ActiveRecord::Base.connection. In multi-database
        # setups (Rails 6.1+), ActiveRecord::Base may not have a connection pool
        # registered — pools are on the abstract classes that declare connects_to.
        #
        # Arel::Table stores the owning model as @klass (set via the klass:
        # keyword argument in its constructor). There is no public accessor,
        # so we use instance_variable_get with a fallback to ActiveRecord::Base
        # for cases where klass is nil (e.g. hand-built Arel tables).
        klass = attribute.relation.instance_variable_get(:@klass) || ActiveRecord::Base
        cache = klass.connection.schema_cache

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
