# frozen_string_literal: true

require "arel/nodes/binary"

module Arel
  module Nodes
    class Overlap < Arel::Nodes::Binary
      def operator
        :"&&"
      end
    end

    class Contains < Arel::Nodes::Binary
      def operator
        :>>
      end
    end

    class ContainsHStore < Arel::Nodes::Binary
      def operator
        :"@>"
      end
    end

    class ContainsArray < Arel::Nodes::Binary
      def operator
        :"@>"
      end
    end

    class ContainedInArray < Arel::Nodes::Binary
      def operator
        :"<@"
      end
    end

    module Inet
      class ContainsEquals < Arel::Nodes::Binary
        def operator
          :">>="
        end
      end

      class ContainedWithin < Arel::Nodes::Binary
        def operator
          :<<
        end
      end

      class ContainedWithinEquals < Arel::Nodes::Binary
        def operator
          :"<<="
        end
      end

      class ContainsOrContainedWithin < Arel::Nodes::Binary
        def operator
          :"&&"
        end
      end
    end

    class Node
      def group_or(right)
        Arel::Nodes::Or.new self, Arel::Nodes::Grouping.new(right)
      end
    end
  end
end
