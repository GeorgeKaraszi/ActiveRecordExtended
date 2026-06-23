# frozen_string_literal: true

module ActiveRecordExtended
  # Holds gem-wide configuration plus the per-query (thread-local) override used
  # to decide whether CTEs are built by this gem or delegated to Rails' native
  # CTE support.
  class Configuration
    # :extended -> use this gem's CTE implementation (default, historical behavior)
    # :native   -> delegate to Rails' native CTE implementation
    VALID_CTE_HANDLERS = [:extended, :native].freeze

    attr_reader :cte_handler

    def initialize
      @cte_handler = :extended
    end

    # @param [Symbol] value
    def cte_handler=(value)
      value = value.to_sym
      unless VALID_CTE_HANDLERS.include?(value)
        raise ArgumentError.new("cte_handler must be one of #{VALID_CTE_HANDLERS.inspect}, got #{value.inspect}")
      end

      @cte_handler = value
    end
  end

  THREAD_NATIVE_CTE_KEY = :active_record_extended_native_cte

  class << self
    # @return [ActiveRecordExtended::Configuration]
    def config
      @config ||= Configuration.new
    end

    # @yield [ActiveRecordExtended::Configuration]
    def configure
      yield(config) if block_given?
      config
    end

    # Resolves whether the current call site should use Rails' native CTE
    # handling. The per-query thread-local override takes precedence over the
    # global handler.
    # @return [Boolean]
    def native_cte?
      return native_cte_override unless native_cte_override.nil?

      config.cte_handler == :native
    end

    # Forces Rails' native CTE handling for every `.with` (and nested subquery
    # `.with`) built inside the block. Restores the previous value afterwards so
    # the blocks may be nested.
    #
    #   ActiveRecordExtended.with_native_cte do
    #     User.with(recent: Profile.where(active: true))
    #   end
    #
    # @yield the scope of queries that should use native CTE handling
    def with_native_cte
      previous = native_cte_override
      self.native_cte_override = true
      yield
    ensure
      self.native_cte_override = previous
    end

    # Forces this gem's CTE handling inside the block, regardless of the global
    # handler. Mainly useful to carve an exception out of a `:native` default.
    #
    # @yield the scope of queries that should use the gem's CTE handling
    def with_extended_cte
      previous = native_cte_override
      self.native_cte_override = false
      yield
    ensure
      self.native_cte_override = previous
    end

    private

    def native_cte_override
      Thread.current[THREAD_NATIVE_CTE_KEY]
    end

    def native_cte_override=(value)
      Thread.current[THREAD_NATIVE_CTE_KEY] = value
    end
  end
end
