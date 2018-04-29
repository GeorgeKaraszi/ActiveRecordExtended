# frozen_string_literal: true

require "arel/predications"

module Arel
  module Predications
    def overlap(other)
      Nodes::Overlap.new(self, Nodes.build_quoted(other, self))
    end

    def contains(other)
      Nodes::Contains.new self, Nodes.build_quoted(other, self)
    end
  end
end
