# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module WithCTE
      class WithChain
        def initialize(scope)
          @scope = scope
        end

        def recursive(*args)
          @scope.tap do |scope|
            scope.with_values    += args
            scope.recursive_value = true
          end
        end
      end

      def with_values
        @values[:with] || []
      end

      def with_values?
        !(@values[:with].nil? || @values[:with].empty?)
      end

      def with_values=(values)
        @values[:with] = values
      end

      def recursive_value=(value)
        raise ImmutableRelation if @loaded
        @values[:recursive] = value
      end

      def recursive_value
        @values[:recursive]
      end
      alias recursive_value? recursive_value

      def with(opts = :chain, *rest)
        return WithChain.new(spawn) if opts == :chain
        opts.blank? ? self : spawn.with!(opts, *rest)
      end

      def with!(opts = :chain, *rest)
        return WithChain.new(self) if opts == :chain
        self.with_values += [opts] + rest
        self
      end

      def build_with_hashed_value(with_value)
        with_value.map do |name, expression|
          select =
            case expression
            when String
              Arel.sql("(#{expression})")
            when ActiveRecord::Relation, Arel::SelectManager
              Arel.sql("(#{expression.to_sql})")
            end
          next if select.nil?
          Arel::Nodes::As.new(Arel.sql(PG::Connection.quote_ident(name.to_s)), select)
        end
      end

      def build_with(arel)
        with_statements = with_values.flat_map do |with_value|
          case with_value
          when String, Arel::Nodes::As
            with_value
          when Hash
            build_with_hashed_value(with_value)
          end
        end.compact

        return if with_statements.empty?
        recursive_value? ? arel.with(:recursive, with_statements) : arel.with(with_statements)
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::WithCTE)
