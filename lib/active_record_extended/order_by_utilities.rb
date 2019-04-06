# frozen_string_literal: true

require "active_record"

module ActiveRecordExtended
  module OrderByUtilities
    def inline_order_by(arel_node, ordering_args)
      return arel_node unless scope_preprocess_ordering_args(ordering_args)

      Arel::Nodes::InfixOperation.new("ORDER BY", arel_node, ordering_args)
    end

    def scope_preprocess_order_args(ordering_args)
      return false if ordering_args.blank? || !@scope.respond_to?(:preprocess_order_args, true)

      # Sanitation check / resolver (ActiveRecord::Relation#preprocess_order_args)
      @scope.send(:preprocess_order_args, ordering_args)
      ordering_args
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
