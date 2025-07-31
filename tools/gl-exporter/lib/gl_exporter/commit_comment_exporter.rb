class GlExporter
  class CommitCommentExporter
    include UserContentRewritable
    include Writable
    include Authorable
    include Attachable

    attr_reader :commit, :commit_comment, :project_exporter, :archiver

    def initialize(commit, commit_comment, project_exporter:)
      @commit_comment = commit_comment
      @project_exporter = project_exporter
      @archiver = current_export.archiver
      commit_comment["commit"] = commit
      commit_comment["repository"] = project
      commit_comment["author"] && export_user(commit_comment["author"]["username"])
    end

    # Alias for `commit_comment`
    #
    # @return [Hash]
    def model
      commit_comment
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
      commit_comment["created_at"]
    end

    # Instruct the exporter to rewrite the user content for the `commit_comment`
    def rewrite!
      rewrite_user_content!
    end

    # Instruct the exporter to export the `commit_comment`.
    def export
      serialize("commit_comment", commit_comment)
      extract_attachments("commit_comment", commit_comment)
    end

  end
end
