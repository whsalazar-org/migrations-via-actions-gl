class GlExporter
  module Logging
    def logger
      @logger ||= Logger.new(File.join(logs_dir, "gl-exporter.log"))
    end

    def output_logger
      @output_logger ||= Logger.new(STDOUT).tap do |logger|
        logger.progname = "gl-exporter"
      end
    end

    private

    def logs_dir
      "./log/"
    end
  end
end
