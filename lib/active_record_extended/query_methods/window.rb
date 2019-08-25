# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module Window
      class DefineWindowChain
        include ::ActiveRecordExtended::Utilities::Support
        include ::ActiveRecordExtended::Utilities::OrderBy

        def initialize(scope, window_name)
          @scope        = scope
          @window_name  = window_name
        end

        def partition_by(*partitions, order_by: nil)
          @scope.window_values! << {
            window_name:  to_arel_sql(@window_name),
            partition_by: flatten_to_sql(partitions),
            order_by:     order_by_expression(order_by),
          }

          @scope
        end
      end

      class WindowSelectBuilder
        include ::ActiveRecordExtended::Utilities::Support

        def initialize(window_function, args, window_name)
          @window_function = window_function
          @win_args        = to_sql_array(args)
          @over            = to_arel_sql(window_name)
        end

        def build_select(alias_name = nil)
          window_arel = generate_named_function(@window_function, *@win_args).over(@over)

          if alias_name.nil?
            window_arel
          else
            nested_alias_escape(window_arel, alias_name)
          end
        end
      end

      def window_values
        @values.fetch(:window, [])
      end

      def window_values!
        @values[:window] ||= []
      end

      def window_values?
        !window_values.empty?
      end

      def window_values=(*values)
        @values[:window] = values.flatten(1)
      end

      def define_window(name)
        spawn.define_window!(name)
      end

      def define_window!(name)
        DefineWindowChain.new(self, name)
      end

      def select_window(window_function, *args, over:, as: nil)
        spawn.select_window!(window_function, args, over: over, as: as)
      end

      def select_window!(window_function, *args, over:, as: nil)
        args.flatten!
        args.compact!

        select_statement = WindowSelectBuilder.new(window_function, args, over).build_select(as)
        _select!(select_statement)
      end

      def build_windows(arel)
        window_values.each do |window_value|
          window = arel.window(window_value[:window_name]).partition(window_value[:partition_by])
          window.order(window_value[:order_by]) if window_value[:order_by]
        end
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecordExtended::QueryMethods::Window)
