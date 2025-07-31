class GlExporter
  class MergeRequestNoteExporter
    include UserContentRewritable
    include Writable
    include Authorable
    include Attachable

    attr_reader :merge_request_note, :merge_request_exporter, :archiver

    attr_accessor :merge_request_notes

    def initialize(merge_request_note, merge_request_exporter:)
      @merge_request_note = merge_request_note
      @merge_request_exporter = merge_request_exporter
      @current_export = current_export
      @archiver = current_export.archiver
      merge_request_note["merge_request"] = merge_request
      merge_request_note["author"] && export_user(merge_request_note["author"]["username"])
    end

    # Alias for `merge_request_note`
    #
    # @return [Hash]
    def model
      merge_request_note
    end

    # References the parent merge_request
    #
    # @return [Hash]
    def merge_request
      merge_request_exporter.merge_request
    end

    # References the project for the export
    #
    # @return [Hash]
    def project
      merge_request_exporter.project
    end

    # References the current export
    #
    # @return [GlExporter]
    def current_export
      merge_request_exporter.current_export
    end

    # References the parent project exporter object
    #
    # @return [GlExporter::ProjectExporter]
    def project_exporter
      merge_request_exporter.project_exporter
    end

    # Instruct the exporter to export the `merge_request_note` as well as any
    # inline attachments from the `merge_request_note`'s body content
    def export
      extract_attachments("issue_comment", merge_request_note)
      serialize("issue_comment", merge_request_note)
    end

    def export_as_issue_note
      merge_request_note["noteable_type"] = "Issue"
      merge_request_note["issue"] = merge_request
      export
    end
  end
end
