# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module WithCTE # rubocop:disable Metrics/ModuleLength
      class WithCTE
        include ActiveRecordExtended::Utilities::Support
        include Enumerable
        extend  Forwardable

        def_delegators :@with_values, :empty?, :blank?, :present?
        attr_reader :with_values, :with_keys, :materialized_keys, :not_materialized_keys

        # @param [ActiveRecord::Relation] scope
        def initialize(scope)
          @scope = scope
          reset!
        end

        # @return [Enumerable] Returns the order for which CTE's were imported as.
        def each
          return to_enum(:each) unless block_given?

          with_keys.each do |key|
            yield(key, with_values[key])
          end
        end
        alias each_pair each

        # @param [Hash, WithCTE] value
        def with_values=(value)
          reset!
          pipe_cte_with!(value)
        end

        # @return [Boolean]
        def materialized_key?(key)
          materialized_keys.include?(key.to_sym)
        end

        # @return [Boolean]
        def not_materialized_key?(key)
          not_materialized_keys.include?(key.to_sym)
        end

        # @param [Hash, WithCTE] value
        def pipe_cte_with!(value) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
          return if value.nil? || value.empty?

          value.each_pair do |name, expression|
            sym_name = name.to_sym
            next if with_values.key?(sym_name)

            # Ensure we follow FIFO pattern.
            # If the parent has similar CTE alias keys, we want to favor the parent's expressions over its children's.
            if expression.is_a?(ActiveRecord::Relation) && expression.with_values?
              expression.cte = expression.cte.dup if expression.cte

              # Add child's materialized keys to the parent
              @materialized_keys += expression.cte.materialized_keys
              @not_materialized_keys += expression.cte.not_materialized_keys

              pipe_cte_with!(expression.cte)
              expression.cte.reset!
            end

            @with_keys            |= [sym_name]
            @with_values[sym_name] = expression
          end

          value.reset! if value.is_a?(WithCTE)
        end

        def reset!
          @with_keys   = []
          @with_values = {}
          @materialized_keys = Set.new
          @not_materialized_keys = Set.new
        end
      end

      class WithChain
        # @param [ActiveRecord::Relation] scope
        def initialize(scope)
          @scope       = scope
          @scope.cte ||= WithCTE.new(scope)
        end

        # @param [Hash, WithCTE] args
        def recursive(args)
          @scope.tap do |scope|
            scope.recursive_value = true
            scope.cte.pipe_cte_with!(args)
          end
        end

        # @param [Hash, WithCTE] args
        def materialized(args)
          if ActiveRecordExtended::Config.cte_deprecation_warnings_enabled?
            CTE_DEPRECATOR.warn(
              <<~DEPRECATION_WARNING
                [ActiveRecordExtended] WithCTE support is deprecated for Rails 7.2+ (native CTE support).
                Materialized CTEs are not supported in Rails 7.2+. Rails 8.0+ supports them natively.
              DEPRECATION_WARNING
            )
          end

          @scope.tap do |scope|
            args.each_pair do |name, _expression|
              sym_name = name.to_sym
              raise ArgumentError.new("CTE already set as not_materialized") if scope.cte.not_materialized_key?(sym_name)

              scope.cte.materialized_keys << sym_name
            end
            scope.cte.pipe_cte_with!(args)
          end
        end

        # @param [Hash, WithCTE] args
        def not_materialized(args)
          if ActiveRecordExtended::Config.cte_deprecation_warnings_enabled?
            CTE_DEPRECATOR.warn(
              <<~DEPRECATION_WARNING
                [ActiveRecordExtended] WithCTE support is deprecated for Rails 7.2+ (native CTE support).
                Not materialized CTEs are not supported in natively in Rails 7.2+. Rails 8.0+ supports them natively.
              DEPRECATION_WARNING
            )
          end

          @scope.tap do |scope|
            args.each_pair do |name, _expression|
              sym_name = name.to_sym
              raise ArgumentError.new("CTE already set as materialized") if scope.cte.materialized_key?(sym_name)

              scope.cte.not_materialized_keys << sym_name
            end
            scope.cte.pipe_cte_with!(args)
          end
        end
      end

      # @return [WithCTE]
      def cte
        @values[:cte]
      end

      # @param [WithCTE] cte
      def cte=(cte)
        raise TypeError.new("Must be a WithCTE class type") unless cte.is_a?(WithCTE)

        @values[:cte] = cte
      end

      # @return [Boolean]
      def with_values?
        target =
          if ActiveRecordExtended::Config.should_use_native_cte?(force: forced_native_adapter?)
            ActiveRecordExtended::Config.raise_on_native_cte_error { with_values }
          else
            warn_deprecation!
            cte
          end
        !(target.nil? || target.empty?)
      end

      def forced_native_adapter?
        @values[:override_adapter] == :native
      end

      # @return [Boolean]
      def recursive_value?
        !(!@values[:recursive])
      end

      # @param [Hash, WithCTE] values
      def with_values=(values)
        if ActiveRecordExtended::Config.should_use_native_cte?(force: forced_native_adapter?)
          ActiveRecordExtended::Config.raise_on_native_cte_error { super }
        else
          warn_deprecation!
          cte.with_values = values
        end
      end

      # @param [Boolean] value
      def recursive_value=(value)
        raise ImmutableRelation if @loaded

        @values[:recursive] = value
      end

      def override_adapter=(value)
        raise ImmutableRelation if @loaded

        @values[:override_adapter] = value
      end

      # Forces a relation query to use the native Rails CTE process instead of the legacy pathway,
      # despite the configuration set within ActiveRecordExtended::Config.cte_adapter_mode.
      #
      # @example
      # User.with_native(comments: Comment.where(id: 1))
      def with_native(...)
        spawn.with_native!(...)
      end

      def with_native!(...)
        self.override_adapter = :native
        self.with_values |= [cte.with_values] if cte.present? # Merge legacy CTEs with native CTEs

        with(...)
      end

      def with(...)
        if ActiveRecordExtended::Config.should_use_native_cte?(force: forced_native_adapter?)
          ActiveRecordExtended::Config.raise_on_native_cte_error { super }
        else
          legacy_with(...)
        end
      ensure
        track_cte_usage!(:with)
      end

      # Things to Solve:
      # When an application has ActiveRecordExtended::Config.should_use_native_cte? enabled
      # When application passes in an argument to force native or legacy

      def with!(...)
        if ActiveRecordExtended::Config.should_use_native_cte?(force: forced_native_adapter?)
          ActiveRecordExtended::Config.raise_on_native_cte_error { super }
        else
          warn_deprecation!
          legacy_with!(...)
        end
      end

      def build_with(arel)
        if ActiveRecordExtended::Config.should_use_native_cte?(force: forced_native_adapter?)
          ActiveRecordExtended::Config.raise_on_native_cte_error { super }
        else
          legacy_build_with(arel)
        end
      end

      private

      # @param [Hash, WithCTE] opts
      def legacy_with(opts = :chain, *rest)
        return WithChain.new(self) if opts == :chain

        opts.blank? ? self : spawn.with!(opts, *rest)
      end

      # @param [Hash, WithCTE] opts
      def legacy_with!(opts = :chain, *rest)
        case opts
        when :chain
          WithChain.new(self)
        when :recursive
          WithChain.new(self).recursive(*rest)
        else
          tap do |scope|
            scope.cte ||= WithCTE.new(self)
            scope.cte.pipe_cte_with!(opts)
          end
        end
      end

      def legacy_build_with(arel)
        return unless with_values?

        cte_statements = cte.map do |name, expression|
          grouped_expression = cte.generate_grouping(expression)
          cte_name           = cte.to_arel_sql(cte.double_quote(name.to_s))
          grouped_expression = add_materialized_modifier(grouped_expression, cte, name)

          Arel::Nodes::As.new(cte_name, grouped_expression)
        end

        if recursive_value?
          arel.with(:recursive, cte_statements)
        else
          arel.with(cte_statements)
        end
      end

      def add_materialized_modifier(expression, cte, name)
        if cte.materialized_key?(name)
          Arel.sql("MATERIALIZED #{expression.to_sql}")
        elsif cte.not_materialized_key?(name)
          Arel.sql("NOT MATERIALIZED #{expression.to_sql}")
        else
          expression
        end
      end

      def warn_deprecation!
        return unless ActiveRecordExtended::Config.cte_deprecation_warnings_enabled?
        return if ActiveRecordExtended::Config.should_use_native_cte?
        return if @values[:warned_cte_deprecation]

        @values[:warned_cte_deprecation] = true

        CTE_DEPRECATOR.warn(
          "[ActiveRecordExtended] CTE support will be deprecated in the next major release. " \
          "Set the adapter mode to \"ActiveRecordExtended::Config.cte_adapter_mode = :native\" " \
          "to begin the migration process over to using the official Rails CTE support."
        )
      end

      def track_cte_usage!(method_name)
        return unless ActiveRecordExtended::Config.cte_migration_tracking
        return unless ActiveRecordExtended::Config.cte_usage_callback

        ActiveRecordExtended::Config.cte_usage_callback.call(
          method:    method_name,
          locations: caller(1..2),
          timestamp: Time.current
        )
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::WithCTE)
