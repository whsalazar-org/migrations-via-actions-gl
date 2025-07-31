class GlExporter
  # Serializes Protected Branches from GitLab repositories
  #
  # #### Model Example:
  #
  # ```
  # {
  #     "name": "master",
  #     "commit": {
  #         "id": "fc40f8230aab1a10e16c70b2706e2d2a6164eea0",
  #         "short_id": "fc40f823",
  #         "title": "Merge branch 'merged-fork-pr' into 'master'\r",
  #         "created_at": "2016-11-23T20:43:35.000+00:00",
  #         "parent_ids": [
  #             "3a1811f3cb96e9bc426f6ee3544a2cf4f7d5f3fd",
  #             "75d5f1a0a3f8c07806512a647d16d60c4cd1c36f"
  #         ],
  #         "message": "Merge branch 'merged-fork-pr' into 'master'\r\n\r\nMerged Fork PR\r\n\r\nSee merge request !7",
  #         "author_name": "Kyle Macey",
  #         "author_email": "shout@kylemacey.com",
  #         "authored_date": "2016-11-23T20:43:35.000+00:00",
  #         "committer_name": "Kyle Macey",
  #         "committer_email": "shout@kylemacey.com",
  #         "committed_date": "2016-11-23T20:43:35.000+00:00"
  #     },
  #     "merged": false,
  #     "protected": true,
  #     "developers_can_push": false,
  #     "developers_can_merge": false
  # }
  # ```

  class ProtectedBranchSerializer < BaseSerializer
    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        type:                                     "protected_branch",
        name:                                     name,
        url:                                      url,
        creator_url:                              creator_url,
        repository_url:                           repository_url,
        admin_enforced:                           admin_enforced,
        block_deletions_enforcement_level:        block_deletions_enforcement_level,
        block_force_pushes_enforcement_level:     block_force_pushes_enforcement_level,
        dismiss_stale_reviews_on_push:            dismiss_stale_reviews_on_push,
        pull_request_reviews_enforcement_level:   pull_request_reviews_enforcement_level,
        require_code_owner_review:                require_code_owner_review,
        required_status_checks_enforcement_level: required_status_checks_enforcement_level,
        strict_required_status_checks_policy:     strict_required_status_checks_policy,
        authorized_actors_only:                   authorized_actors_only,
        authorized_user_urls:                     authorized_user_urls,
        authorized_team_urls:                     authorized_team_urls,
        dismissal_restricted_user_urls:           dismissal_restricted_user_urls,
        dismissal_restricted_team_urls:           dismissal_restricted_team_urls,
        required_status_checks:                   required_status_checks,
      }
    end

    # Pull Requests require that the repository and branch be attached before serialization
    def valid?(gl_model)
      gl_model["repository"] && gl_model["creator"]
    end

    private

    def name
      gl_model["name"]
    end

    def url
      if Gitlab.api_v3?
        url_for_model(gl_model, type: "protected_branch")
      else
        url = url_for_model(gl_model, type: "protected_branch")
        repository_full_path = gl_model["repository"]["namespace"]["full_path"]
        url.sub(repository_full_path, repository_full_path.gsub("/", "-"))
      end
    end

    # set the export user to the protected branch creator
    def creator_url
      url_for_model(gl_model["creator"], type: "owner")
    end

    def repository_url
      url = url_for_model(gl_model["repository"])

      if Gitlab.api_v3?
        url_for_model(gl_model["repository"])
      else
        repository_full_path = gl_model["repository"]["namespace"]["full_path"]
        url.sub(repository_full_path, repository_full_path.gsub("/", "-"))
      end
    end

    def admin_enforced
      true
    end

    # Sets the enforcement protection levels for branch deletions.
    # 0 => :off        no protection
    # 1 => :non_admins non-admins cannot delete the branch
    # 2 -> :everyone   everyone, including an admin, cannot delete the branch
    #
    def block_deletions_enforcement_level
      2
    end

    # Sets the enforcement protection levels for branch pushes.
    # 0 => :off        no protection
    # 1 => :non_admins non-admins cannot force push to branch
    # 2 -> :everyone   everyone, including an admin, cannot force push to the branch
    #
    def block_force_pushes_enforcement_level
      2
    end

    def dismiss_stale_reviews_on_push
      false
    end

    def pull_request_reviews_enforcement_level
      "off"
    end

    def require_code_owner_review
      false
    end

    def required_status_checks_enforcement_level
      "off"
    end

    def strict_required_status_checks_policy
      false
    end

    def authorized_actors_only
      false
    end

    def authorized_user_urls
      []
    end

    def authorized_team_urls
      []
    end

    def dismissal_restricted_user_urls
      []
    end

    def dismissal_restricted_team_urls
      []
    end

    def required_status_checks
      []
    end
  end
end
