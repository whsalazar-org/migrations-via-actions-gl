class GlExporter
  class SafeTransaction
    attr_reader :logger, :state, :response

    HANDLED_ERRORS = %w{Rugged::OdbError Faraday::ResourceNotFound}

    def initialize(logger)
      @logger = logger
      @state = :new
    end

    def safely(*args, &block)
      provided_errors = args.flatten.map(&:to_s)
      begin
        @response = block.call
        @state = :success
      rescue StandardError => e
        if (provided_errors + HANDLED_ERRORS).include?(e.class.name)
          @caught_error = e
          logger.error(e.message)
          @state = :error
        else
          raise
        end
      end
      self
    end

    def error(&block)
      if state == :error
        block.call(@caught_error)
      end
      self
    end

    def success(&block)
      if state == :success
        block.call
      end
      self
    end
  end

  module SafeExecution
    def safely(*args, &block)
      logger = send(self.class.class_variable_get(:@@safe_exception_logger))
      SafeTransaction.new(logger).safely(*args, &block)
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def log_handled_exceptions_to(logger)
        class_variable_set(:@@safe_exception_logger, logger)
      end
    end
  end
end
