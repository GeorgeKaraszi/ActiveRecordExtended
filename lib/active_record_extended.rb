# frozen_string_literal: true

require "active_record_extended/version"

require "active_record"
require "active_record/relation"
require "active_record/relation/merger"
require "active_record/relation/query_methods"

module ActiveRecordExtended
  extend ActiveSupport::Autoload

  AR_VERSION_GTE_6_1 = Gem::Requirement.new(">= 6.1").satisfied_by?(ActiveRecord.gem_version)

  module Utilities
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :OrderBy
      autoload :Support
    end
  end

  module Patch
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :ArrayHandlerPatch
      autoload :RelationPatch
      autoload :WhereClausePatch
    end
  end

  module QueryMethods
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :AnyOf
      autoload :Either
      autoload :FosterSelect
      autoload :Inet
      autoload :Json
      autoload :Unionize
      autoload :WhereChain
      autoload :Window
      autoload :WithCTE
    end
  end

  def self.eager_load!
    super
    ActiveRecordExtended::Utilities.eager_load!
    ActiveRecordExtended::Patch.eager_load!
    ActiveRecordExtended::QueryMethods.eager_load!
  end
end

ActiveSupport.on_load(:active_record) do
  require "active_record_extended/arel"
  ActiveRecordExtended.eager_load!
end
