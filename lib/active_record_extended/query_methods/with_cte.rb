# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module WithCTE
      class WithCTE
        include ::ActiveRecordExtended::Utilities::Support
        include Enumerable
        extend Forwardable
        attr_reader :with_values, :with_keys
        def_delegators :@with_values, :empty?, :blank?, :present?

        def initialize(scope)
          @scope = scope.spawn
          reset!
        end

        # @return [Enumerable] Returns the order for which CTE's were imported as.
        def each(&block)
          return to_enum(:each) unless block_given?

          with_keys.each do |key|
            block.call(key, with_values[key])
          end
        end
        alias each_pair each

        # @param [Hash, WithCTE] value
        def with_values=(value)
          reset!
          reverse_merge!(value)
        end

        # @param [Hash, WithCTE] value
        def reverse_merge!(value)
          return if value.nil? || value.empty?

          value.each do |name, expression|
            next if with_values.key?(name)

            @with_keys        << name
            @with_values[name] = expression

            # Ensure we follow FIFO pattern.
            # If the parent has similar CTE alias keys, we want to favor the parent's expressions over its children's.
            if expression.is_a?(ActiveRecord::Relation) && expression.with_values?
              reverse_merge!(expression.cte)
              expression.cte.reset!
            end
          end

          value.reset! if value.is_a?(WithCTE)
        end

        def reset!
          @with_keys   = []
          @with_values = {}
        end
      end

      class WithChain
        def initialize(scope)
          @scope       = scope
          @scope.cte ||= WithCTE.new(scope)
        end

        def recursive(args)
          @scope.tap do |scope|
            scope.recursive_value = true
            scope.cte.reverse_merge!(args)
          end
        end
      end

      # @return [WithCTE]
      def cte
        @values[:cte]
      end

      # @param [WithCTE] cte
      def cte=(cte)
        raise TypeError, "Must be a WithCTE class type" unless cte.is_a?(WithCTE)
        @values[:cte] = cte
      end

      def with_values?
        !(cte.nil? || cte.empty?)
      end

      def with_values=(values)
        cte.with_values = values
      end

      def recursive_value=(value)
        raise ImmutableRelation if @loaded
        @values[:recursive] = value
      end

      def recursive_value
        @values[:recursive]
      end
      alias recursive_value? recursive_value

      # @param [Hash, WithCTE] opts
      def with(opts = :chain, *rest)
        return WithChain.new(spawn) if opts == :chain
        opts.blank? ? self : spawn.with!(opts, *rest)
      end

      # @param [Hash, WithCTE] opts
      def with!(opts = :chain, *_rest)
        return WithChain.new(self) if opts == :chain

        (self.cte ||= WithCTE.new(self)).reverse_merge!(opts)
        self
      end

      def build_with(arel)
        return unless with_values?

        cte_statements = cte.map do |name, expression|
          grouped_expression = cte.group_when_needed(expression)
          cte_name           = cte.to_arel_sql(cte.double_quote(name.to_s))
          Arel::Nodes::As.new(cte_name, grouped_expression)
        end

        return if cte_statements.empty?
        recursive_value? ? arel.with(:recursive, cte_statements) : arel.with(cte_statements)
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::WithCTE)
