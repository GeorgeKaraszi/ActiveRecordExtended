# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module Select
      class SelectHelper
        include ::ActiveRecordExtended::Utilities
        FALLBACK_OPTS = {}.freeze

        def initialize(scope)
          @scope = scope
        end

        def build_foster_select(*args)
          flatten_safely(args).each do |select_arg|
            case select_arg
            when String, Symbol
              append_select!(select_arg)
            when Hash
              select_arg.each_pair do |alias_name, options_or_column|
                if options_or_column.is_a?(Array)
                  options = options_or_column.detect { |opts| opts.is_a?(Hash) } || FALLBACK_OPTS
                  append_select!(options_or_column.first, alias_name, options[:cast_as])
                else
                  append_select!(options_or_column, alias_name)
                end
              end
            else
              next
            end
          end
        end

        private

        def append_select!(query, alias_name = nil, cast_as = nil)
          @scope._select!(to_casted_query(query, alias_name, cast_as))
        end

        def to_casted_query(query, alias_name, cast_as)
          case cast_as.to_s
          when /^(array|true)$/
            wrap_with_array(query, alias_name)
          when /array_agg/
            wrap_with_agg_array(query, alias_name, cast_as)
          else
            alias_name.presence ? nested_alias_escape(query, alias_name) : query
          end
        end
      end

      def foster_select(*args)
        raise ArgumentError, "Call `forster_select' with at least one field" if args.empty?
        spawn._foster_select!(*args)
      end

      def _foster_select!(*args)
        SelectHelper.new(self).build_foster_select(*args)
        self
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::Select)
