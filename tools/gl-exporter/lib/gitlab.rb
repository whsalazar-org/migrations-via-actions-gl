require "active_support/notifications"

# The GitLab API client wrapper. Utilizes Farday and FileStore cache to prevent
# the same API request from being called multiple times. All calls to GitLab's
# API should originate from within this class.
class Gitlab
  class << self
    attr_writer :token
    attr_writer :ssl_verify

    RECORDS_PER_PAGE=100

    # Fetch Gitlab username either from attribute or environment variable.
    # The username is used for cloning git repositories via https
    #
    # @return [String] Gitlab username
    def username
      @username ||= ENV['GITLAB_USERNAME']
    end

    # Fetch GitLab API token either from attribute or environment variable
    #
    # @return [String] GitLab API token
    def token
      raise(
        ArgumentError,
        "Must define \`GITLAB_API_PRIVATE_TOKEN\`"
      ) unless ENV['GITLAB_API_PRIVATE_TOKEN']

      @token ||= ENV['GITLAB_API_PRIVATE_TOKEN']
    rescue ArgumentError => exception
      abort(exception.message)
    end

    attr_writer :api_endpoint

    # Fetch GitLab API endpoint either from attribute or environment variable
    #
    # @return [String] GitLab API endpoint
    def api_endpoint
      @api_endpoint ||= ENV['GITLAB_API_ENDPOINT'] || "https://gitlab.com/api/v4"
    end

    # Enable or disable GitLab SSL verification for API and git access
    #
    # @return [Hash]
    def ssl_verify
      if @ssl_verify.nil?
        @ssl_verify = !%w(0 false).include?(ENV['GITLAB_SSL_VERIFY'])
      end
      @ssl_verify
    end

    # Get the version information for the GitLab instance
    #
    # @return [Hash]
    def version
      get("version")
    end

    def api_v3?
      # TODO: Autodetect API version.
      api_endpoint.include?("api/v3")
    end

    def issue_id_key
      api_v3? ? "id" : "iid"
    end

    # Search for a namespace on GitLab
    #
    # @example
    #   Gitlab.namespaces(search: 'gitlabhq')
    # @param [String] search namespace to search for
    # @return [Array]
    def namespaces(search:)
      connection.get do |request|
        request.url "namespaces"
        request.params["search"] = search
      end.body
    end

    # Get a single group
    #
    # @param [String] name the slug of the group you want to fetch
    # @return [Hash] API body for the requested group
    def group(name)
      name = URI.encode_www_form_component(name)
      get("groups/#{name}")
    end

    # Get a single user or currently authenticated user
    #
    # @param [String, Integer, NilClass] name_or_id the slug or id of the user
    #   you want to fetch
    # @return [Hash] When a name or id is provided, returns the requested user.
    #   When name_or_id is nil, the currently authenticated user is returned.
    def user(name_or_id=nil)
      if name_or_id
        warn "Using this method with an argument is deprecated and you should " \
          "either use Gitlab.user_by_id or Gitlab.user_by_username"
      end

      case name_or_id
      when Integer, /\A\d+\z/
        user_by_id(name_or_id)
      when String
        user_by_username(name_or_id)
      else
        get("user")
      end
    end

    # Get a single user by ID
    #
    # @param [String, Integer] id the id of the user
    #   you want to fetch
    # @return [Hash] The returned user
    def user_by_id(id)
      get("users/#{id}")
    end

    # Get a single user by username
    #
    # @param [String] username the username of the user
    #   you want to fetch
    # @return [Hash] The returned user
    def user_by_username(username)
      get("users?username=#{username}").first
    end

    # Get branches for a given project
    # @param [#to_s] project_id the id of the project
    # @return [Array<Hash>]
    def branches(project_id)
      pagination = api_v3? ? false : :standard
      get("projects/#{project_id}/repository/branches", auto_paginate: pagination)
    end

    # Get a branch for a given project
    # @param [#to_s] project_id the id of the project
    # @param [#to_s] branch_name the name of the branch
    # @return [Array<Hash>]
    def branch(project_id, branch_name)
      get("projects/#{project_id}/repository/branches/#{branch_name}")
    end

    # Get commits for a given project.
    #
    # @param [#to_s] project_id the id of the project to get commits for
    # @return [Array<Hash>]
    def commits(project_id)
      pagination = api_v3? ? :legacy : :standard
      get("projects/#{project_id}/repository/commits", auto_paginate: pagination)
    end

    # Get information about a specific commit
    #
    # @param [#to_s] project_id the id of the project that owns the commit
    # @param [#to_s] commit_id the sha of the commit
    # @return [Hash]
    def commit(project_id, commit_id)
      get("projects/#{project_id}/repository/commits/#{commit_id}")
    end

    # Get commit comments for a given commit
    #
    # @param [#to_s] project_id the id of the project that owns the commit
    # @param [#to_s] commit_id the sha of the commit to get comments for
    # @return [Array<Hash>]
    def commit_comments(project_id, commit_id)
      get("projects/#{project_id}/repository/commits/#{commit_id}/comments", auto_paginate: :standard)
    end

    # Get a single issue
    #
    # @param [#to_s] project_id the id of the issue's project
    # @param [#to_s] issue_id the id of the issue
    # @return [Hash]
    def issue(project_id, issue_id)
      get("projects/#{project_id}/issues/#{issue_id}")
    end

    # Get issues for a given project
    #
    # @param [#to_s] project_id the id of the project to get issues for
    # @return [Array<Hash>]
    def issues(project_id)
      get("projects/#{project_id}/issues", auto_paginate: :standard)
    end

    # Get a single issue note
    #
    # @param [#to_s] project_id the id of the issue note's project
    # @param [#to_s] issue_id the id of the issue the note belongs to
    # @param [#to_s] issue_note_id the id of the issue note
    # @return [Hash]
    def issue_note(project_id, issue_id, issue_note_id)
      get("projects/#{project_id}/issues/#{issue_id}/notes/#{issue_note_id}")
    end

    # Get issue notes for a given project issue
    #
    # @param [#to_s] project_id the id of the issue's project
    # @param [#to_s] issue_id the id of the issue to get notes for
    # @return [Array<Hash>]
    def issue_notes(project_id, issue_id)
      get("projects/#{project_id}/issues/#{issue_id}/notes", auto_paginate: :standard)
    end

    # Get a single merge request
    #
    # @param [#to_s] project_id the id of the merge request's project
    # @param [#to_s] merge_request_id the id of the merge request
    # @return [Hash]
    def merge_request(project_id, merge_request_id)
      get("projects/#{project_id}/merge_requests/#{merge_request_id}")
    end

    # Get the commits for a given merge request.
    #
    # @param [#to_s] project_id the id of the merge request's project
    # @param [#to_s] merge_request_id the id of the merge request
    # @return [Array<Hash>]
    def merge_request_commits(project_id, merge_request_id)
      get("projects/#{project_id}/merge_requests/#{merge_request_id}/commits", auto_paginate: :standard)
    end

    # Get the merge requests for a given project
    #
    # @param [#to_s] project_id the id of the project to get merge requests for
    # @return [Array<Hash>]
    def merge_requests(project_id)
      get("projects/#{project_id}/merge_requests", auto_paginate: :standard)
    end

    # Get a single merge request note
    #
    # @param [#to_s] project_id the id of the merge request note's project
    # @param [#to_s] merge_request_id the id of the merge request the note
    #   belongs to
    # @param [#to_s] merge_request_note_id the id of the merge request note
    # @return [Hash]
    def merge_request_note(project_id, merge_request_id, merge_request_note_id)
      get("projects/#{project_id}/merge_requests/#{merge_request_id}/notes/#{merge_request_note_id}")
    end

    # Get issue notes for a given project merge request
    #
    # @param [#to_s] project_id the id of the merge request's project
    # @param [#to_s] merge_request_id the id of the merge request to get notes for
    # @return [Array<Hash>]
    def merge_request_notes(project_id, merge_request_id)
      get("projects/#{project_id}/merge_requests/#{merge_request_id}/notes", auto_paginate: :standard)
    end

    # Get the milestones for a given project
    #
    # @param [#to_s] project_id the id of the project to get milestones for
    # @return [Array<Hash>]
    def milestones(project_id)
      get("projects/#{project_id}/milestones", auto_paginate: :standard)
    end

    # Get a single milestone
    #
    # @param [#to_s] project_id the id of the milestone's project
    # @param [#to_s] milestone_id the id of the milestone
    # @return [Hash]
    def milestone(project_id, milestone_id)
      get("projects/#{project_id}/milestones/#{milestone_id}")
    end

    # Get a project
    # @param [String] namespace the project owner's URL slug
    # @param [String] project_name the project's URL slug
    # @return [Hash]
    def project(namespace, project_name)
      path = URI.encode_www_form_component("#{namespace}/#{project_name}")
      get("projects/#{path}")
    end

    # Get a project using project ID.
    # @param [String] project_id the project's URL slug
    # @return [Hash]
    def project_by_id(project_id)
      get("projects/#{project_id}")
    end

    # Get the team members for a given project.
    #
    # @param [#to_s] project_id the id of the project to get labels for
    # @return [Array<Hash>]
    def project_team_members(project_id)
      get("projects/#{project_id}/members", auto_paginate: :standard)
    end

    # Get the labels for a given project. Results are not paginated
    #
    # @param [#to_s] project_id the id of the project to get labels for
    # @return [Array<Hash>]
    def labels(project_id)
      return get("projects/#{project_id}/labels") if api_v3?

      get("projects/#{project_id}/labels", auto_paginate: :standard)
    end

    # Get the webhooks for a given project. Results are not paginated
    #
    # @param [#to_s] project_id the id of the project to get webhooks for
    # @return [Array<Hash>]
    def webhooks(project_id)
      get("projects/#{project_id}/hooks")
    end

    # Get the a specific webhook for a given project.
    #
    # @param [#to_s] project_id the id of the project to get webhooks for
    # @param [#to_s] hook_id the id of the webhook to get
    # @return [Array<Hash>]
    def webhook(project_id, hook_id)
      get("projects/#{project_id}/hooks/#{hook_id}")
    end

    # Get the members for a given group. Results are not paginated
    #
    # @param [#to_s] group_name the name of the group to get members for
    # @return [Array<Hash>]
    def group_members(group_name)
      group_name = URI.encode_www_form_component(group_name)
      get("groups/#{group_name}/members/all", auto_paginate: :standard).select{ |member| member["membership_state"] == "active" || member["state"] == "active" }
    end

    # Get the tags for a given project. Results are not paginated
    #
    # @param [#to_s] project_id the id of the project to get tags for
    # @return [Array<Hash>]
    def tags(project_id)
      get("projects/#{project_id}/repository/tags")
    end

    # Get a single tag
    #
    # @param [#to_s] project_id the id of the tag's project
    # @param [#to_s] name the URL slug of the tag
    # @return [Hash]
    def tag(project_id, name)
      get("projects/#{project_id}/repository/tags/#{name}")
    end

    # Make a POST request to GitLab's API.
    #
    # @note Does not currently accept a `body` parameter.
    #
    # @param [String] path the URL path to send the POST request to.
    # @return the response status
    def post(path)
      builder = UrlBuilder.new(path)
      response = connection.post(builder.to_s)
      response.status
    end

    # Lock (Archive in GitLab-speak) a given project.
    #
    # @param [#to_s] project_id the id fo the project to lock
    # @return the response status
    def lock(project_id)
      post("projects/#{project_id}/archive")
    end

    # Unlock (Unarchive in GitLab-speak) a given project.
    #
    # @param [#to_s] project_id the id fo the project to unlock
    # @return the response status
    def unlock(project_id)
      post("projects/#{project_id}/unarchive")
    end

    # Make a GET request to GitLab's API
    #
    # @param [String] path the URL path to send the GET request to
    # @param [Symbol,Boolean] auto_paginate what pagination method to use for
    # auto pagination
    # @option auto_paginate :standard use GitLab's documented API pagination
    # @option auto_paginate :legacy use GitLab's undocumented legacy API
    # pagination
    # @option auto_paginate false do not auto paginate results
    # @return the response body
    def get(path, auto_paginate: false)
      case auto_paginate
      when :standard
        get_all(path)
      when :legacy
        get_all_legacy(path)
      else
        get_one(path)
      end
    end

    # Fetch records and auto paginate using GitLab's documented API pagination
    #
    # @param [String] path the URL path to send the GET request to
    # @return [Array]
    def get_all(path)
      page = 1
      body = []
      while page.present? do
        builder = UrlBuilder.new(path, params: { page: page, per_page: RECORDS_PER_PAGE })
        response = connection.get(builder.to_s)
        body += response.body
        page = response.headers["x-next-page"]
      end
      body
    end

    # Fetch records and auto paginate using GitLab's undocumented legacy API
    # pagination
    #
    # @param [String] path the URL path to send the GET request to
    # @return [Array]
    def get_all_legacy(path)
      page = 0
      body = []
      while true do
        builder = UrlBuilder.new(path, params: { page: page, per_page: RECORDS_PER_PAGE })
        response = connection.get(builder.to_s)
        results = response.body
        break if results.empty?
        body += results
        page += 1
      end
      body
    end

    # Get a single record or not paginated collection of records
    #
    # @param [String] path the URL path to send the GET request to
    # @return [Array,Hash]
    def get_one(path)
      builder = UrlBuilder.new(path)
      connection.get(builder.to_s).body
    end

    # The Faraday connection object for making requests to GitLab API
    #
    # @return [Faraday::Connection]
    def connection
      @connection ||= Faraday.new(faraday_options) do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        faraday.response :raise_error
        faraday.use :http_cache, store: http_cache, serializer: Marshal
        faraday.use Faraday::CacheHeaders
        faraday.response :json, :content_type => /\bjson$/
        faraday.adapter Faraday.default_adapter  # make requests with Net::HTTP
      end
    end

    # The Faraday connection options
    #
    # @return [Faraday::Connection]
    def faraday_options
      {
        headers: {"PRIVATE-TOKEN" => token},
        ssl:     {verify: ssl_verify}
      }
    end

    # Faraday's cache store
    #
    # @return [ActiveSupport::Cache::FileStore]
    def http_cache
      @http_cache ||= ActiveSupport::Cache::FileStore.new(http_cache_path)
    end

    # The path to the http cache on disk
    #
    # @return [String]
    def http_cache_path
      Dir.mktmpdir("gl_exporter_http_cache")
    end
  end
end
