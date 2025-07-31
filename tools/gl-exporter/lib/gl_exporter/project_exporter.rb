class GlExporter
  # @!attribute [r] project
  #   @return [Hash] the project to be exported
  # @!attribute [r] archiver
  #   @return [GlExporter::ArchiveBuilder] the instance of the archiver for this export job
  # @!attribute [r] models
  #   @return [Array] the optional model types to be exported
  # @!attribute [r] team_builder
  #   @return [GlExporter::TeamBuilder] the instance of the team builder for this export job
  # @!attribute [r] current_export
  #   @return [GlExporter] the instance of this export job
  # @!attribute [rw] issues
  #   @return [Array] the child issues of the project being exported
  # @!attribute [rw] merge_requests
  #   @return [Array] the child merge requests of the project being exported
  # @!attribute [rw] commit_comments
  #   @return [Array] the child commit comments of the project being exported
  class ProjectExporter
    include Storable
    include Writable
    include Authorable

    attr_reader :project, :archiver, :models, :team_builder, :current_export

    attr_accessor :issues, :merge_requests, :commit_comments, :rewritten_ids

    # Create a new instance of ProjectExporter
    #
    # @param [Hash] project the GitLab project to be exported
    # @param [GlExporter] current_export the current export object
    def initialize(project, current_export: GlExporter.new)
      @project = project
      @current_export = current_export
      @archiver = current_export.archiver
      @models = current_export.models_to_export & OPTIONAL_MODELS
      @team_builder = current_export.team_builder

      @issues = []
      @merge_requests = []
      @commit_comments = []
      @rewritten_ids = {
        issues: {},
        merge_requests: {},
      }
    end

    # Alias for `project`
    #
    # @return [Hash]
    def model
      project
    end

    def project_name
      project["path_with_namespace"]
    end

    def export
      current_export.output_logger.info "Exporting project #{project_name}..."
      export_authenticated_user

      # GitLab is inconsistent with their API where group-owned projects don't
      # have an "owner" attribute.
      project["owner"] = project_owner
      project["labels"] = Gitlab.labels(project["id"])
      project["collaborators"] = export_collaborators
      project["wiki_enabled"] = false unless models.include?('wiki')
      current_export.output_logger.info "Cloning repository..."
      archiver.clone_repo(project)
      # export optional models
      models.each do |model|
        send("export_#{model}")
      end
      export_tags
      export_milestones
      export_protected_branches

      serialize "repository", project

      renumber_issues_and_merge_requests(skip: current_export.without_renumbering)
      rewrite_commit_comment_references_to_issues_and_merge_requests
      export_stored_project_data
    end

    # Serializes and exports data for MigratableResources pertaining to @project
    def export_stored_project_data
      current_export.output_logger.info "Exporting issues, merge requests, and commit comments..."
      [issues, merge_requests, commit_comments].flatten.sort_by(&:created_at).each(&:export)
    end

    # Caches `#export_owner_of_project` in memory
    def project_owner
      @project_owner ||= export_owner_of_project
    end

    # Exports the group or user that owns @project
    #
    # @return [Hash] owner of GitLab Project
    def export_owner_of_project
      if Gitlab.api_v3?
        owner, kind = get_owner_and_kind(project["namespace"]["path"])
      else
        owner, kind = get_owner_and_kind(project["namespace"]["full_path"])
      end
      send("export_#{kind}", owner)
      owner
    end

    # Exports the user performing the export
    def export_authenticated_user
      @authenticated_user ||= export_user(Gitlab.user)
    end

    # Serialize and export a GitLab Group as a GitHub Organization. Also exports
    # the group members and their group memberships
    #
    # @param [Hash] owner the GitLab group to be exported
    def export_group(owner)
      owner["members"] = Gitlab.group_members(Gitlab.api_v3? ? owner["path"] : owner["full_path"])
      serialize "organization", owner
      team_builder.add_project(
        model_url_service.url_for_model(owner),
        model_url_service.url_for_model(project),
      )
      serialized_users = owner["members"].map do |member|
        # Since we're already looping here, we sneak in the addition to TeamBuilder
        team_builder.add_member(
          model_url_service.url_for_model(owner),
          model_url_service.url_for_model(member),
          team_access(member["access_level"]),
        )
        # Each org member needs an associated user created
        export_user(member["username"])
      end
    end

    # Serialize and export the project collaborators
    #
    # @return [Array] the GitLab project collaborators
    def export_collaborators
      Gitlab.project_team_members(project["id"]).each do |collaborator|
        export_user(collaborator["username"])
      end
    end

    # Prepare the Commit comments for @project to be exported
    def prepare_commit_comments_for_export
      current_export.output_logger.info "Collecting data for commit comments..."
      Gitlab.commits(project["id"]).each do |commit|
        Gitlab.commit_comments(project["id"], commit["id"]).each do |commit_comment|
          prepare_commit_comment_for_export(commit, commit_comment)
        end
      end
    end

    # Prepare a GitLab Commit comment to be exported
    #
    # @param [Hash] commit the parent GitLab Commit of the Commit comment to be exported
    # @param [Hash] commit_comment the GitLab Commit comment to be exported
    def prepare_commit_comment_for_export(commit, commit_comment)
      commit_comments.push(
        CommitCommentExporter.new(commit, commit_comment, project_exporter: self)
      )
    end

    # Serialize and export the milestones for @project
    def export_milestones
      return unless project["issues_enabled"] || project["merge_requests_enabled"]
      current_export.output_logger.info "Exporting milestones..."
      milestone_titles = []
      Gitlab.milestones(project["id"]).each do |m|
        i = 0
        new_title = m["title"]
        while milestone_titles.include?(new_title)
          i += 1
          new_title = "#{m["title"]} (#{i})"
        end
        milestone_titles << new_title
        m["title"] = new_title
      end.each(&method(:export_milestone))
    end

    # Serialize and export a GitLab Milestone
    #
    # @param [Hash] milestone the GitLab milestone to be exported
    def export_milestone(milestone)
      milestone["repository"] = project
      milestone["user"] = Gitlab.user
      serialize("milestone", milestone)
    end

    # Serialize and export the protected branches for @project
    def export_protected_branches
      current_export.output_logger.info "Exporting protected branches..."
      Gitlab.branches(project["id"]).each do |branch|
        next unless branch["protected"]
        export_protected_branch(branch)
      end
    end

    # Serialize and export a GitLab protected branch
    #
    # @param [Hash] protected_branch the GitLab Protected Branch to be exported
    def export_protected_branch(protected_branch)
      ProtectedBranchExporter.new(
        protected_branch,
        project_exporter: self
      ).export
    end

    # Attach GitLab hooks to @project to be serialized
    def export_hooks
      project["webhooks"] = Gitlab.webhooks(project["id"])
    end

    # Prepare the Issues for @project to be exported
    def prepare_issues_for_export
      return unless project["issues_enabled"]
      current_export.output_logger.info "Collecting data for issues and comments..."
      Gitlab.issues(project["id"]).each(&method(:prepare_issue_for_export))
    end

    # Prepare a GitLab Issue to be exported
    #
    # @param [Hash] issue the GitLab Issue to be exported
    def prepare_issue_for_export(issue)
      issues.push(
        IssueExporter.new(issue, project_exporter: self)
      )
    end

    # Prepare the Merge Requests for @project to be exported
    def prepare_merge_requests_for_export
      return unless project["merge_requests_enabled"]
      current_export.output_logger.info "Collecting data for merge requests and comments..."
      Gitlab.merge_requests(project["id"]).each(&method(:prepare_merge_request_for_export))
    end

    # Prepare a GitLab Merge Request to be exported
    #
    # @param [Hash] merge_request the GitLab Merge Request to be exported
    def prepare_merge_request_for_export(merge_request)
      merge_requests.push(
        MergeRequestExporter.new(merge_request,
          project_exporter: self,
          project_owner: project_owner,
        )
      )
    end

    alias_method :export_issues, :prepare_issues_for_export
    alias_method :export_merge_requests, :prepare_merge_requests_for_export
    alias_method :export_commit_comments, :prepare_commit_comments_for_export

    # Serialize and export the GitLab tags for @project as GitHub Releases
    def export_tags
      current_export.output_logger.info "Exporting tags..."
      Gitlab.tags(project["id"]).each do |tag|
        if tag["release"]
          export_tag(tag)
        end
      end
    end

    # Serialize and export a GitLab tag
    #
    # @param [Hash] tag the GitLab tag to be exported
    def export_tag(tag)
      tag["repository"] = project
      tag["user"] = Gitlab.user # attribute all tags to export user
      serialize("release", tag)
    end

    def export_wiki
      return unless project["wiki_enabled"]
      current_export.output_logger.info "Cloning project wiki..."
      archiver.clone_wiki(project)
    end

    # Goes through the stored Issues and Pull requests to rewrite their ids
    # sequentially, then rewrites the mentions to them in Pull Requests, Issues,
    # and comments
    #
    # @param [Symbol, NilClass] skip the model that will not be renumbered
    def renumber_issues_and_merge_requests(skip: nil)
      current_export.output_logger.info "Renumbering issues and merge requests chronologically..."
      index, models = case skip
      when :issues
        [
          issues.map { |issue| issue.model["iid"] }.max.to_i + 1,
          merge_requests
        ]
      when :merge_requests
        [
          merge_requests.map { |merge_request| merge_request.model["iid"] }.max.to_i + 1,
          issues
        ]
      else
        [
          1,
          [issues, merge_requests].flatten
        ]
      end
      models.sort_by(&:created_at).each.with_index(index) do |m, i|
        m.renumber!(i)
      end
      (issues + merge_requests).each(&:rewrite!)
    end

    # Goes through the stored Commit Comments and rewrites references to Issues
    # and Merge requests to newly renumbered Issues and Pull Requests
    def rewrite_commit_comment_references_to_issues_and_merge_requests
      current_export.output_logger.info "Rewriting issues and merge requests references in commit comments..."
      models = [commit_comments].flatten.sort_by(&:created_at)
      models.each(&:rewrite!)
    end

    # For a given owner name, determine if it is a user or group and send back
    # complete information about the owner
    #
    # @param [String] name the name of the owner
    # @return [Array] an Array containing the kind of owner and information
    #   about that owner
    def get_owner_and_kind(name)
      if user = Gitlab.user_by_username(name)
        [user, "user"]
      elsif group = Gitlab.group(name)
        [group, "group"]
      else
        raise NoNamespaceFound, name
      end
    end

    # GUEST     = 10
    # REPORTER  = 20
    # DEVELOPER = 30
    # MASTER    = 40
    # OWNER     = 50
    PERMISSION_MAP = {
      10 => "read",
      20 => "triage",
      30 => "write",
      40 => "maintain",
      50 => "admin",
    }
    def team_access(access_level)
      PERMISSION_MAP[access_level]
    end

    class NoNamespaceFound < StandardError
      def initialize(namespace)
        @namespace = namespace
      end

      def message
        "Namespace with name `#{@namespace}` not found"
      end
    end
  end
end
