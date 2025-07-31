class GlExporter
  class IssueNoteExporter
    include UserContentRewritable
    include Writable
    include Authorable
    include Attachable

    attr_reader :issue_note, :issue_exporter, :archiver

    attr_accessor :issue_notes

    def initialize(issue_note, issue_exporter:)
      @issue_note = issue_note
      @issue_exporter = issue_exporter
      @archiver = current_export.archiver
      issue_note["issue"] = issue
      issue_note["author"] && export_user(issue_note["author"]["username"])
    end

    # Alias for `issue_note`
    #
    # @return [Hash]
    def model
      issue_note
    end

    # References the parent issue
    #
    # @return [Hash]
    def issue
      issue_exporter.issue
    end

    # References the project for the export
    #
    # @return [Hash]
    def project
      issue_exporter.project
    end

    # References the current export
    #
    # @return [GlExporter]
    def current_export
      issue_exporter.current_export
    end

    # References the parent project exporter object
    #
    # @return [GlExporter::ProjectExporter]
    def project_exporter
      issue_exporter.project_exporter
    end

    # Instruct the exporter to export the `issue_note` as well as any inline
    # attachments from the `issue_note`'s body content
    def export
      extract_attachments("issue_comment", issue_note)
      serialize("issue_comment", issue_note)
    end
  end
end
