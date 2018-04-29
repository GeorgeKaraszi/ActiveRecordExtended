# frozen_string_literal: true

require "active_record"

require "postgres_extended/active_record/query_methods_decorator"
require "postgres_extended/active_record/array_handler_decorator"

if ActiveRecord::VERSION::MAJOR >= 5
  if ActiveRecord::VERSION::MINOR >= 2
    require "postgres_extended/active_record/5_2/relation_decorator"
  else
    require "postgres_extended/active_record/5_0/relation_decorator"
  end
end
