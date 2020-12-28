module Hermes
  class Configuration
    attr_accessor :adapter, :clock, :hutch, :application_prefix, :logger,
      :background_processor, :enqueue_method, :event_handler, :rpc_call_timeout,
      :instrumenter, :distributed_tracing_database_uri, :distributed_tracing_database_table,
      :distributes_tracing_mapper, :database_error_handler, :error_notification_service

    def configure_hutch
      yield hutch
    end

    def self.configure
      yield configuration
    end

    def rpc_call_timeout
      @rpc_call_timeout || 10
    end

    def instrumenter
      @instrumenter || Hermes::NullInstrumenter
    end

    def hutch
      @hutch ||= HutchConfig.new
    end

    def logger
      @logger ||= Hermes::Logger.new
    end

    def store_distributed_traces?
      !!distributed_tracing_database_uri
    end

    def distributed_tracing_database_table
      @distributed_tracing_database_table || "hermes_distributed_traces"
    end

    def distributes_tracing_mapper=(mapper)
      raise ArgumentError.new("mapper must espond to :call method") if !mapper.respond_to?(:call)
      @distributes_tracing_mapper = mapper
    end

    def distributes_tracing_mapper
      @distributes_tracing_mapper || ->(attributes) { attributes }
    end

    def error_notification_service
      @error_notification_service || Hermes::NullErrorNotificationService
    end

    def database_error_handler
      @database_error_handler || Hermes::DatabaseErrorHandler.new(error_notification_service: error_notification_service)
    end

    class HutchConfig
      attr_accessor :uri
    end
    private_constant :HutchConfig
  end
end
