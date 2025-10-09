# frozen_string_literal: true

require "active_record_extended/version"

require "active_record"
require "active_record/relation"
require "active_record/relation/merger"
require "active_record/relation/query_methods"

module ActiveRecordExtended
  extend ActiveSupport::Autoload

  AR_VERSION_GTE_8_0 = Gem::Requirement.new(">= 8.0").satisfied_by?(ActiveRecord.gem_version)
  AR_VERSION_GTE_7_2 = Gem::Requirement.new(">= 7.2").satisfied_by?(ActiveRecord.gem_version)
  CTE_DEPRECATOR     = ActiveSupport::Deprecation.new(ActiveRecordExtended::VERSION, "ActiveRecordExtended")

  module Config
    ARE_CTE_ERROR = Class.new(StandardError)

    mattr_accessor :cte_adapter_mode, default: :legacy
    # Options:
    # - :auto   => Automatically use Rails native if available
    # - :native => Always use Rails native (will raise errors if ActiveRecord Version < 7.2)
    # - :legacy => Always use legacy WITH cte creation

    mattr_accessor :cte_deprecation_warnings, default: true # Enable deprecation warnings for CTE legacy usage
    mattr_accessor :cte_migration_tracking, default: false # Enable callback for tracking CTE usage during migration
    mattr_accessor :cte_usage_callback, default: nil # Callback for tracking CTE usage during migration

    def self.cte_deprecation_warnings_enabled?
      cte_deprecation_warnings && AR_VERSION_GTE_7_2
    end

    def self.should_use_native_cte?
      return false if cte_adapter_mode == :legacy
      return true if cte_adapter_mode == :native

      cte_adapter_mode == :auto && AR_VERSION_GTE_7_2
    end

    def self.raise_on_native_cte_error
      if AR_VERSION_GTE_7_2
        yield
      else
        raise ARE_CTE_ERROR.new("Rails < 7.2 does not support CTEs")
      end
    end

    def self.configure
      yield self
    end
  end

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
