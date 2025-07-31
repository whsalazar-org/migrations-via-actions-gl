class GlExporter

  # Serializes Repositories from GitLab's Projects
  #
  # #### Model Example:
  #
  # ```
  # {"id"=>877707,
  #  "description"=>"Repository Contribution Graphs in your terminal!",
  #  "default_branch"=>"master",
  #  "tag_list"=>[],
  #  "public"=>false,
  #  "archived"=>false,
  #  "visibility_level"=>0,
  #  "ssh_url_to_repo"=>"git@gitlab.com:kylemacey/repo-contrib-graph.git",
  #  "http_url_to_repo"=>"https://gitlab.com/kylemacey/repo-contrib-graph.git",
  #  "web_url"=>"https://gitlab.com/kylemacey/repo-contrib-graph",
  #  "owner"=>
  #   {"name"=>"Kyle Macey",
  #    "username"=>"kylemacey",
  #    "id"=>414903,
  #    "state"=>"active",
  #    "avatar_url"=>"https://secure.gravatar.com/avatar/e7bc3ce1dbb0fcaa9bb00bf10628526e?s=80&d=identicon",
  #    "web_url"=>"https://gitlab.com/u/kylemacey"},
  #  "name"=>"repo-contrib-graph",
  #  "name_with_namespace"=>"Kyle Macey / repo-contrib-graph",
  #  "path"=>"repo-contrib-graph",
  #  "path_with_namespace"=>"kylemacey/repo-contrib-graph",
  #  "issues_enabled"=>true,
  #  "merge_requests_enabled"=>true,
  #  "wiki_enabled"=>false,
  #  "builds_enabled"=>true,
  #  "snippets_enabled"=>false,
  #  "created_at"=>"2016-02-16T22:55:38.924Z",
  #  "last_activity_at"=>"2016-02-16T22:55:39.251Z",
  #  "shared_runners_enabled"=>true,
  #  "creator_id"=>414903,
  #  "namespace"=>
  #   {"id"=>486715,
  #    "name"=>"kylemacey",
  #    "path"=>"kylemacey",
  #    "owner_id"=>414903,
  #    "created_at"=>"2016-02-16T16:36:31.652Z",
  #    "updated_at"=>"2016-02-16T16:36:31.652Z",
  #    "description"=>"",
  #    "avatar"=>nil,
  #    "membership_lock"=>false,
  #    "share_with_group_lock"=>false},
  #  "avatar_url"=>nil,
  #  "star_count"=>0,
  #  "forks_count"=>0,
  #  "open_issues_count"=>3,
  #  "public_builds"=>true,
  #  "permissions"=>{"project_access"=>{"access_level"=>40, "notification_level"=>3}, "group_access"=>nil}}
  # ```
  class RepositorySerializer < BaseSerializer
    include ProjectHelpers

    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        :type           => "repository",
        :url            => url,
        :owner          => owner,
        :name           => gl_model["name"],
        :description    => description,
        :website        => nil,
        :private        => private?,
        :has_issues     => gl_model["issues_enabled"],
        :has_wiki       => has_wiki?,
        :has_downloads  => has_downloads?,
        :labels         => labels,
        :webhooks       => webhooks,
        :collaborators  => collaborators,
        :created_at     => gl_model["created_at"],
        # @todo: Perhaps extract this into some configuration space?
        :git_url        => git_url,
        :default_branch => gl_model["default_branch"]
      }.tap do |hash|
        if has_wiki?
          hash[:wiki_url] = wiki_url
        end
      end
    end

    private

    def url
      if Gitlab.api_v3?
        url_for_model(gl_model)
      else
        full_path = gl_model["namespace"]["full_path"]
        url_for_model(gl_model).sub(full_path, full_path.gsub("/", "-"))
      end
    end

    def owner
      if gl_model["owner"]
        url_for_model(gl_model["owner"], type: "owner")
      end
    end

    def description
      gl_model["description"].to_s.gsub(/[[:cntrl:]]/, " ").gsub(/\s+/, ' ')
    end

    def private?
      if Gitlab.api_v3?
        visibility_level = gl_model['visibility_level']
        visibility_level.zero? || visibility_level.ten?
      else
        %w[private internal].include?(gl_model.fetch('visibility'))
      end
    end

    def has_wiki?
      gl_model["wiki_enabled"]
    end

    def has_downloads?
      downloads_key = Gitlab.api_v3? ? "builds_enabled" : "jobs_enabled"
      gl_model[downloads_key]
    end

    def labels
      Array.wrap(gl_model["labels"]).map do |label|
        label["repository"] = gl_model
        LabelSerializer.new.serialize(label)
      end
    end

    def webhooks
      Array.wrap(gl_model["webhooks"]).map do |webhook|
        WebhookSerializer.new.serialize(webhook)
      end
    end

    def collaborators
      Array.wrap(gl_model["collaborators"]).map do |project_team_member|
        CollaboratorSerializer.new.serialize(project_team_member)
      end
    end

    def git_url
      "tarball://root/repositories/#{org_name}.git"
    end

    def wiki_url
      "tarball://root/repositories/#{org_name}.wiki.git"
    end

    def org_name
      @org_name ||= org_from_path_with_namespace(gl_model["path_with_namespace"])
    end
  end
end
