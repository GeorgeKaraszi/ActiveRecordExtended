# frozen_string_literal: true

module ActiveRecordExtended
  module Utilities
    # We need to ensure we can flatten nested ActiveRecord::Relations
    # that might have been nested due to the (splat)*args parameters
    #
    # Note: calling `Array.flatten[!]/1` will actually remove all AR relations from the array
    def self.flatten_scopes(values)
      return [values] unless values.is_a?(Array)

      values.inject([]) do |new_ary, value|
        value.is_a?(Array) ? new_ary + flatten_scopes(value) : new_ary << value
      end.compact
    end
  end
end
