class GlExporter
  class ProtectedBranchExporter
    include Writable
    include Authorable
    include SafeExecution

    log_handled_exceptions_to :logger

    attr_reader :protected_branch, :project_exporter, :archiver

    def initialize(protected_branch, project_exporter:)
      @protected_branch = protected_branch
      @project_exporter = project_exporter
      @archiver = current_export.archiver
      protected_branch["repository"] = project
      protected_branch["creator"] = project_exporter.project_owner
    end

    # Alias for `protected_branch`
    #
    # @return [Hash]
    def model
      protected_branch
    end

    # References the project for the export
    #
    # @return [Hash]
    def project
      project_exporter.project
    end

    # References the current export
    #
    # @return [GlExporter]
    def current_export
      project_exporter.current_export
    end

    def logger
      current_export.logger
    end

    # Instruct the exporter to export the `protected_branch`
    def export
      serialize("protected_branch", protected_branch)
    end
  end
end
