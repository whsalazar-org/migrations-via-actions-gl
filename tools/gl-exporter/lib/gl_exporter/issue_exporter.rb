class GlExporter
  class IssueExporter
    include UserContentRewritable
    include Writable
    include Authorable
    include Attachable

    attr_reader :issue, :project_exporter, :archiver, :original_id

    attr_accessor :issue_notes

    def initialize(issue, project_exporter:)
      @issue = issue
      @original_id = issue[Gitlab.issue_id_key]
      @project_exporter = project_exporter
      @archiver = current_export.archiver
      @issue_notes = []
      issue["repository"] = project
      issue["author"] && export_user(issue["author"]["username"])
      issue["assignee"] && export_user(issue["assignee"]["username"])
      prepare_issue_notes_for_export(issue)
    end


    # Alias for `issue`
    #
    # @return [Hash]
    def model
      issue
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

    # Accessor for the model's created timestamp
    #
    # @return [String]
    def created_at
      issue["created_at"]
    end

    # Change the id for the attached `issue` and record the mapping to the
    # project exporter
    #
    # @param [Integer] id the new id for the issue
    def renumber!(id)
      project_exporter.rewritten_ids[:issues][original_id] = id
      issue[Gitlab.issue_id_key] = id
    end

    # Instruct the exporter to rewrite the user content for the `issue` as well
    # as any attached issue notes
    def rewrite!
      rewrite_user_content!
      issue_notes.each(&:rewrite_user_content!)
    end

    # Instruct the exporter to export the `issue` as well as any attached notes.
    # Also extracts any inline attachments from the `issue`'s body content
    def export
      serialize("issue", issue)
      extract_attachments("issue", issue)
      issue_notes.each(&:export)
    end

    private

    # Serialize and export the Notes for a given GitLab Issue as GitHub Comments
    #
    # @param [Hash] issue the GitLab Issue for which the notes will be exported
    def prepare_issue_notes_for_export(issue)
      Gitlab.issue_notes(project["id"], issue[Gitlab.issue_id_key]).each do |issue_note|
        prepare_issue_note_for_export(issue_note, issue)
      end
    end

    # Serialize and export a GitLab Issue Note
    #
    # @param [Hash] issue_note the GitLab Issue Note to export
    # @param [Hash] issue the parent GitLab Issue of issue_note
    def prepare_issue_note_for_export(issue_note, issue)
      issue_notes.push(
        IssueNoteExporter.new(issue_note,
          issue_exporter: self
        )
      )
    end
  end
end
