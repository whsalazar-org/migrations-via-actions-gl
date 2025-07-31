class GlExporter
  class MergeRequestExporter
    include UserContentRewritable
    include Writable
    include Authorable
    include Attachable
    include SafeExecution

    log_handled_exceptions_to :logger

    attr_reader :merge_request, :project_exporter, :archiver, :original_id

    attr_accessor :merge_request_notes

    def initialize(merge_request, project_exporter:, project_owner:)
      @merge_request = merge_request
      @original_id = merge_request[Gitlab.issue_id_key]
      @project_exporter = project_exporter
      @archiver = current_export.archiver
      @merge_request_notes = []
      merge_request["repository"] = project
      merge_request["owner"] = project_owner
      merge_request["commits"] = Gitlab.merge_request_commits(project["id"], merge_request[Gitlab.issue_id_key])
      merge_request["repo_path"] = archiver.repo_path(project)
      merge_request["author"] && export_user(merge_request["author"]["username"])
      merge_request["assignee"] && export_user(merge_request["assignee"]["username"])
      prepare_merge_request_notes_for_export(merge_request)
    end


    # Alias for `merge_request`
    #
    # @return [Hash]
    def model
      merge_request
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

    # Accessor for the model's created timestamp
    #
    # @return [String]
    def created_at
      merge_request["created_at"]
    end

    # Change the id for the attached `merge_request` and record the mapping to
    # the project exporter
    #
    # @param [Integer] id the new id for the merge_request
    def renumber!(id)
      project_exporter.rewritten_ids[:merge_requests][original_id] = id
      merge_request[Gitlab.issue_id_key] = id
    end

    # Instruct the exporter to rewrite the user content for the `merge_request`
    # as well as any attached merge request notes
    def rewrite!
      rewrite_user_content!
      merge_request_notes.each(&:rewrite_user_content!)
    end

    # Instruct the exporter to export the `merge_request` as well as any
    # attached notes. Also extracts any inline attachments from the
    # `merge_request`'s body content
    def export
      safely {
        no_commits? ? export_as_issue : export_as_pull_request
      }.error {
        export_as_issue
        current_export.output_logger.warn(
          "Exported Merge Request #{original_id} from project #{project["web_url"]} as an Issue"
        )
      }
    end

    def export_as_issue
      serialize("issue", merge_request)
      extract_attachments("issue", merge_request)
      merge_request_notes.each(&:export_as_issue_note)
    end

    def export_as_pull_request
      serialize("pull_request", merge_request)
      extract_attachments("pull_request", merge_request)
      merge_request_notes.each(&:export)
    end

    private

    def no_commits?
      merge_request["commits"].empty?
    end

    # Serialize and export the Notes for a given GitLab Merge Request as GitHub
    # Comments
    #
    # @param [Hash] merge_request the GitLab Merge Request for which the notes
    #   will be exported
    def prepare_merge_request_notes_for_export(merge_request)
      Gitlab.merge_request_notes(project["id"], merge_request[Gitlab.issue_id_key]).each do |merge_request_note|
        prepare_merge_request_note_for_export(merge_request_note, merge_request)
      end
    end

    # Serialize and export a GitLab Merge Request Note
    #
    # @param [Hash] merge_request_note the GitLab Merge Request Note to export
    # @param [Hash] merge_request the parent GitLab Merge Request of merge_request_note
    def prepare_merge_request_note_for_export(merge_request_note, merge_request)
      merge_request_notes.push(
        MergeRequestNoteExporter.new(merge_request_note,
          merge_request_exporter: self,
        )
      )
    end
  end
end
