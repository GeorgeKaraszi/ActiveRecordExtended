# frozen_string_literal: true

require "arel/nodes/binary"

module Arel
  module Nodes
    class Overlap < Arel::Nodes::Binary
    end

    class Contains < Arel::Nodes::Binary
    end

    class ContainsHStore < Arel::Nodes::Binary
    end

    class ContainsArray < Arel::Nodes::Binary
    end

    class ContainedInArray < Arel::Nodes::Binary
    end

    module Inet
      class ContainsEquals < Arel::Nodes::Binary
      end

      class ContainedWithin < Arel::Nodes::Binary
      end

      class ContainedWithinEquals < Arel::Nodes::Binary
      end

      class ContainsOrContainedWithin < Arel::Nodes::Binary
      end
    end
  end
end
