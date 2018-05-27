# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module Inet
      def contained_within(opts, *rest)
        ActiveSupport::Deprecation.warn("#contained_within will soon be deprecated for version 1.0 release. "\
                                        "Please use #inet_contained_within instead.", caller(1))
        inet_contained_within(opts, *rest)
      end

      def inet_contained_within(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::ContainedWithin, "contained_within")
      end

      def contained_within_or_equals(opts, *rest)
        ActiveSupport::Deprecation.warn("#contained_within_or_equals will soon be deprecated for version 1.0 release. "\
                                        "Please use #inet_contained_within_or_equals instead.", caller(1))
        inet_contained_within_or_equals(opts, *rest)
      end

      def inet_contained_within_or_equals(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::ContainedWithinEquals, "contained_within_or_equals")
      end

      def contains_or_equals(opts, *rest)
        ActiveSupport::Deprecation.warn("#contains_or_equals will soon be deprecated for version 1.0 release. "\
                                        "Please use #inet_contains_or_equals instead.", caller(1))
        inet_contains_or_equals(opts, *rest)
      end

      def inet_contains_or_equals(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::ContainsEquals, "contains_or_equals")
      end
    end
  end
end

ActiveRecord::QueryMethods::WhereChain.prepend(ActiveRecordExtended::QueryMethods::Inet)
