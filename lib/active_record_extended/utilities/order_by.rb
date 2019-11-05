# frozen_string_literal: true

require "active_record"

module ActiveRecordExtended
  module Utilities
    module OrderBy
      def inline_order_by(arel_node, ordering_args)
        return arel_node unless scope_preprocess_order_args(ordering_args)

        Arel::Nodes::InfixOperation.new("ORDER BY", arel_node, ordering_args)
      end

      def scope_preprocess_order_args(ordering_args)
        return false if ordering_args.blank? || !@scope.respond_to?(:preprocess_order_args, true)

        # Sanitation check / resolver (ActiveRecord::Relation#preprocess_order_args)
        @scope.send(:preprocess_order_args, ordering_args)
        ordering_args
      end

      # Processes "ORDER BY" expressions for supported aggregate functions
      def order_by_expression(order_by)
        return false unless order_by && order_by.presence.present?

        to_ordered_table_path(order_by)
          .tap { |order_args| process_ordering_arguments!(order_args) }
          .tap { |order_args| scope_preprocess_order_args(order_args) }
      end

      #
      # Turns a hash into a dot notation path.
      #
      # Example:
      # - Using pre-set directions:
      #   [{ products: { position: :asc, id: :desc } }]
      #     #=> [{ "products.position" => :asc, "products.id" => :desc }]
      #
      # - Using fallback directions:
      #   [{products: :position}]
      #     #=> [{"products.position" => :asc}]
      #
      def to_ordered_table_path(args)
        flatten_safely(Array.wrap(args)) do |arg|
          next arg unless arg.is_a?(Hash)

          arg.each_with_object({}) do |(tbl_or_col, obj), new_hash|
            if obj.is_a?(Hash)
              obj.each_pair do |o_key, o_value|
                new_hash["#{tbl_or_col}.#{o_key}"] = o_value
              end
            elsif ::ActiveRecord::QueryMethods::VALID_DIRECTIONS.include?(obj)
              new_hash[tbl_or_col] = obj
            elsif obj.nil?
              new_hash[tbl_or_col.to_s] = :asc
            else
              new_hash["#{tbl_or_col}.#{obj}"] = :asc
            end
          end
        end
      end

      # We'll need to preprocess these arguments for allowing `ActiveRecord::Relation#preprocess_order_args`,
      # to check for sanitization issues and convert over to `Arel::Nodes::[Ascending/Descending]`.
      # Without reflecting / prepending the parent's table name.
      #
      if ActiveRecord.gem_version < Gem::Version.new("5.1")
        # TODO: Rails 5.0.x order logic will *always* append the parents name to the column when its an HASH obj
        #       We should really do this stuff better. Maybe even just ignore `preprocess_order_args` altogether?
        #       Maybe I'm just stupidly over paranoid on just the 'ORDER BY' for some odd reason.
        def process_ordering_arguments!(ordering_args)
          ordering_args.flatten!
          ordering_args.compact!
          ordering_args.map! do |arg|
            next to_arel_sql(arg) unless arg.is_a?(Hash) # ActiveRecord will reflect if an argument is a symbol
            arg.each_with_object([]) do |(field, dir), ordering_object|
              ordering_object << to_arel_sql(field).send(dir.to_s.downcase)
            end
          end.flatten!
        end
      else
        def process_ordering_arguments!(ordering_args)
          ordering_args.flatten!
          ordering_args.compact!
          ordering_args.map! do |arg|
            next to_arel_sql(arg) unless arg.is_a?(Hash) # ActiveRecord will reflect if an argument is a symbol
            arg.each_with_object({}) do |(field, dir), ordering_obj|
              # ActiveRecord will not reflect if the Hash keys are a `Arel::Nodes::SqlLiteral` klass
              ordering_obj[to_arel_sql(field)] = dir.to_s.downcase
            end
          end
        end
      end
    end
  end
end
