# frozen_string_literal: true

module ActiveRecordExtended
  module Utilities
    # We need to ensure we can flatten nested ActiveRecord::Relations
    # that might have been nested due to the (splat)*args parameters
    #
    # Note: calling `Array.flatten[!]/1` will actually remove all AR relations from the array
    def self.flatten_to_sql(values)
      case values
      when ActiveRecord::Relation
        [Arel.sql(values.to_sql)]
      when String
        [Arel.sql(value)]
      when Array
        values.inject([]) do |new_ary, value|
          new_ary + flatten_to_sql(value)
        end
      else
        if values.respond_to?(:to_sql)
          [Arel.sql(values.to_sql)]
        else
          [values]
        end
      end.compact
    end
  end
end
