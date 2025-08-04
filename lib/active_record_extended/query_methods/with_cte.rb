# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module WithCTE
      class WithCTE
        include ActiveRecordExtended::Utilities::Support
        include Enumerable
        extend  Forwardable

        def self.defined_rails_logger?
          defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        end

        def self.cte_disabled?
          # For Rails < 7.2, always allow CTE support (no deprecation)
          # For Rails 7.2+, respect the config setting
          AR_VERSION_GTE_7_2 && ActiveRecordExtended::Config.with_cte_disabled
        end

        def self.cte_deprecation_warnings_enabled?
          AR_VERSION_GTE_7_2 && ActiveRecordExtended::Config.with_cte_deprecation_warnings_enabled
        end

        def_delegators :@with_values, :empty?, :blank?, :present?
        attr_reader :with_values, :with_keys, :materialized_keys, :not_materialized_keys

        # @param [ActiveRecord::Relation] scope
        def initialize(scope)
          if WithCTE.cte_deprecation_warnings_enabled?
            CTE_DEPRECATOR.warn(
              <<~DEPRECATION_WARNING
                [ActiveRecordExtended] WithCTE support is deprecated for Rails 7.2+ (native CTE support).
                Set ActiveRecordExtended::Config.with_cte_disabled = true to disable ActiveRecordExtended CTE support.
                Set ActiveRecordExtended::Config.with_cte_deprecation_warnings_enabled = false to disable warnings.
              DEPRECATION_WARNING
            )
          end

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
          puts "ActiveRecordExtended::WithCTE: [with_values=] value: #{value.inspect}"
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
          puts "ActiveRecordExtended::WithCTE: [pipe_cte_with!] caller #{caller(0..1).join('\n')}"
          puts "ActiveRecordExtended::WithCTE: [pipe_cte_with!] value: #{value.inspect}"
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
          if WithCTE.cte_deprecation_warnings_enabled?
            CTE_DEPRECATOR.warn(
              <<~DEPRECATION_WARNING
                [ActiveRecordExtended] WithCTE support is deprecated for Rails 7.2+ (native CTE support).
                Use the native recursive CTE `with_recursive` instead of `with.recursive`.
              DEPRECATION_WARNING
            )
          end

          if WithCTE.cte_disabled? && WithCTE.defined_rails_logger?
            Rails.logger.debug "ActiveRecordExtended: [recursive] CTE support disabled, calling @scope.with_recursive"

            @scope.tap do |scope|
              scope.with_recursive(args)
              scope.recursive_value = true
            end

            return @scope
          end

          @scope.tap do |scope|
            scope.recursive_value = true
            scope.cte.pipe_cte_with!(args)
          end

          puts "ActiveRecordExtended::WithChain: [recursive] Returning @scope"

          @scope
        end

        # @param [Hash, WithCTE] args
        def materialized(args)
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
        if WithCTE.cte_disabled? && WithCTE.defined_rails_logger?
          return with_values_something.present?
        end

        !(cte.nil? || cte.empty?)
      end

      # @return [Array<Hash>]
      def with_values_something
        puts "ActiveRecordExtended: [with_values_something] caller #{caller(0..1).join('\n')}"

        if WithCTE.cte_disabled? && WithCTE.defined_rails_logger?
          Rails.logger.debug "ActiveRecordExtended: [with_values_somthing] CTE support disabled, calling super"
          return with_values
        end

        with_values? ? [cte.with_values] : []
      end

      # @param [Hash, WithCTE] values
      def with_values=(values)
        puts "ActiveRecordExtended: [with_values=] caller #{caller(0..1).join('\n')}"

        if WithCTE.cte_disabled? && WithCTE.defined_rails_logger?
          super
        else
          cte.with_values = values
        end
      end

      # @param [Boolean] value
      def recursive_value=(value)
        raise ImmutableRelation if @loaded

        @values[:recursive] = value
      end

      # @return [Boolean]
      def recursive_value?
        !(!@values[:recursive])
      end

      # @param [Hash, WithCTE] opts
      def with(opts = :chain, *rest)
        if WithCTE.cte_disabled? && WithCTE.defined_rails_logger?
          Rails.logger.debug "ActiveRecordExtended: [with] CTE support disabled, checking for super call"

          if defined?(super)
            Rails.logger.debug "ActiveRecordExtended: [with] Calling super"
            result =
              case opts
              when :chain
                if rest.any?
                  super(*rest)
                else
                  WithChain.new(spawn)
                end
              when :recursive
                WithChain.new(self).recursive(*rest)
              else
                super(opts)
              end
            Rails.logger.debug "ActiveRecordExtended: [with] Super call completed, result class: #{result.class}"
            Rails.logger.debug "ActiveRecordExtended: [with] Super call SQL: #{result.to_sql[0..100] if result.respond_to?(:to_sql)}"

            return result
          end

          Rails.logger.debug "ActiveRecordExtended: [with] No super defined, raising error"
          raise "WithCTE support is disabled. Set ActiveRecordExtended::Config.with_cte_disabled = false to re-enable."
        end

        if opts == :chain
          return WithChain.new(spawn)
        end

        puts "ActiveRecordExtended: [with] opts.blank? #{opts.blank?}"
        opts.blank? ? self : spawn.with!(opts, *rest)
      end

      # @param [Hash, WithCTE] opts
      def with!(opts = :chain, *rest) # rubocop:disable Metrics/AbcSize
        if WithCTE.cte_disabled? && WithCTE.defined_rails_logger?
          Rails.logger.debug "ActiveRecordExtended: [with!] CTE support disabled, checking for super call"

          if defined?(super)
            case opts
            when :chain
              Rails.logger.debug "ActiveRecordExtended: [with!] Calling super"
              result = super(*rest)
              Rails.logger.debug "ActiveRecordExtended: [with!] Super call completed, result class: #{result.class}"
              Rails.logger.debug "ActiveRecordExtended: [with!] Super call SQL: #{result.to_sql[0..100] if result.respond_to?(:to_sql)}"

              return WithChain.new(result)
            when :recursive
              Rails.logger.debug "ActiveRecordExtended: [with!] Returning WithChain.new(result).recursive(*rest)"
              return WithChain.new(self).recursive(*rest)
            else
              Rails.logger.debug "ActiveRecordExtended: [with!] Returning self with super at cte scope"
              result = super(opts)
              Rails.logger.debug "ActiveRecordExtended: [with!] result class: #{result.class}"
              Rails.logger.debug "ActiveRecordExtended: [with!] Super call SQL: #{result.to_sql[0..100] if result.respond_to?(:to_sql)}"

              tap do |scope|
                scope.cte ||= WithCTE.new(result)
              end

              return result
            end
          end

          Rails.logger.debug "ActiveRecordExtended: [with!] No super defined, raising error"
          raise "WithCTE support is disabled. Set ActiveRecordExtended::Config.with_cte_disabled = false to re-enable."
        end

        case opts
        when :chain
          WithChain.new(self)
        when :recursive
          WithChain.new(self).recursive(*rest)
        else
          result = tap do |scope|
            scope.cte ||= WithCTE.new(self)
            scope.cte.pipe_cte_with!(opts)
          end

          puts "ActiveRecordExtended: [with!] result class: #{result.class}"
          puts "ActiveRecordExtended: [with!] result SQL: #{result.to_sql[0..100] if result.respond_to?(:to_sql)}"

          result
        end
      end

      def build_with(arel)
        if WithCTE.cte_disabled? && WithCTE.defined_rails_logger?
          Rails.logger.debug "ActiveRecordExtended: [build_with] caller #{caller(0..1).join('\n')}"
          Rails.logger.debug "ActiveRecordExtended: [build_with] CTE support disabled, checking for super call"

          if defined?(super)
            Rails.logger.debug "ActiveRecordExtended: [build_with] Arel class: #{arel.class}"
            Rails.logger.debug "ActiveRecordExtended: [build_with] Calling super"
            result = super
            Rails.logger.debug "ActiveRecordExtended: [build_with] Super call completed, result: #{result.class}"
            return result
          end

          Rails.logger.debug "ActiveRecordExtended: [build_with] No fallback available, raising error"
          raise "WithCTE support is disabled. Set ActiveRecordExtended::Config.with_cte_disabled = false to re-enable."
        end

        return unless with_values?

        cte_statements = cte.map do |name, expression|
          puts "ActiveRecordExtended: [build_with] cte.map: name: #{name.inspect}, expression: #{expression.inspect}"
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

      private

      def add_materialized_modifier(expression, cte, name)
        if cte.materialized_key?(name)
          Arel.sql("MATERIALIZED #{expression.to_sql}")
        elsif cte.not_materialized_key?(name)
          Arel.sql("NOT MATERIALIZED #{expression.to_sql}")
        else
          expression
        end
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::WithCTE)
