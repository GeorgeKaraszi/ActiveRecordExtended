# frozen_string_literal: true

require "arel/nodes/binary"
require "arel/nodes/function"

module Arel
  module Nodes
    %w[
      Overlap
      Contains
      ContainsHStore
      ContainsArray
      ContainedInArray
    ].each { |binary_node_name| const_set(binary_node_name, Class.new(::Arel::Nodes::Binary)) }

    %w[
      RowToJson
      JsonBuildObject
      JsonbBuildObject
      ToJson
      ToJsonb
      Array
      ArrayAgg
    ].each do |function_node_name|
      func_klass = Class.new(::Arel::Nodes::Function) do
        def initialize(*args)
          super
          return if @expressions.is_a?(::Array)
          @expressions = @expressions.is_a?(::Arel::Node) ? [@expressions] : [::Arel.sql(@expressions)]
        end
      end

      const_set(function_node_name, func_klass)
    end

    module Inet
      %w[
        Contains
        ContainsEquals
        ContainedWithin
        ContainedWithinEquals
        ContainsOrContainedWithin
      ].each { |binary_node_name| const_set(binary_node_name, Class.new(::Arel::Nodes::Binary)) }
    end
  end
end
