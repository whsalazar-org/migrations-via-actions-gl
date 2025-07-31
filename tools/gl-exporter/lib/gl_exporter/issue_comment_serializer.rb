class GlExporter

  # Serializes Issue Comments from GitLab's Issue Notes
  #
  # #### Model Example:
  #
  # ```
  # "id"=>11735615,
  # "body"=>"It looks like https://gitlab.com/Mouse-Hack/hugo-pages/merge_requests/1 has already :ship: ",
  # "attachment"=>nil,
  # "author"=>
  # {"name"=>"Jon Magic",
  #   "username"=>"jonmagic",
  #   "id"=>529946,
  #   "state"=>"active",
  #   "avatar_url"=>"https://secure.gravatar.com/avatar/7064ad438246a02809c85bcd92cb5f3f?s=80&d=identicon",
  #   "web_url"=>"https://gitlab.com/u/jonmagic"},
  # "created_at"=>"2016-05-10T22:27:02.519Z",
  # "updated_at"=>"2016-05-10T22:27:02.519Z",
  # "system"=>false,
  # "noteable_id"=>2192031,
  # "noteable_type"=>"Issue",
  # "upvote"=>false,
  # "downvote"=>false}
  # ```
  class IssueCommentSerializer < BaseSerializer

    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        :type                   => "issue_comment",
        :url                    => url,
        commentable_type.to_sym => commentable,
        :user                   => user,
        :body                   => body,
        :formatter              => "markdown",
        :created_at             => created_at
      }
    end

    # IssueComments require that the noteable and repository be attached before
    # serialization
    def valid?(gl_model)
      gl_model[noteable_type] && gl_model[noteable_type]["repository"]
    end

    private

    def commentable_type
      noteable_type.gsub("merge", "pull")
    end

    def noteable_type
      if gl_model["noteable_type"] == "Issue"
        "issue"
      elsif gl_model["noteable_type"] == "MergeRequest"
        "merge_request"
      end
    end

    def url
      url_for_model(gl_model, type: "issue_comment")
    end

    def commentable
      url_for_model(gl_model[noteable_type], type: commentable_type)
    end

    def user
      url_for_model(gl_model["author"])
    end

    def body
      gl_model["body"]
    end

    def created_at
      gl_model["created_at"]
    end
  end
end
