class GlExporter

  # Serializes Commit Comments from GitLab's Commit Comments
  #
  # #### Model Example:
  #
  # ```
  # {"note"=>"is this necessary? ",
  # "path"=>"Brewfile",
  # "line"=>5,
  # "line_type"=>nil,
  # "author"=>
  #  {"name"=>"Lizz",
  #   "username"=>"lizzhale",
  #   "id"=>529949,
  #   "state"=>"active",
  #   "avatar_url"=>"https://secure.gravatar.com/avatar/d36cdb93d0f85b5d7b76a183834d4350?s=80&d=identicon",
  #   "web_url"=>"https://gitlab.com/u/lizzhale"},
  # "created_at"=>"2016-05-10T22:23:50.501Z"}
  # ```
  class CommitCommentSerializer < BaseSerializer

    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        :type       => "commit_comment",
        :url        => url,
        :repository => repository,
        :user       => user,
        :body       => body,
        :formatter  => "markdown",
        :path       => path,
        :position   => position,
        :commit_id  => commit_id,
        :created_at => created_at
      }
    end

    # CommitComments require that the commit and repository be attached before
    # serialization
    def valid?(gl_model)
      gl_model["commit"] && gl_model["repository"]
    end

    private

    def url
      url_for_model(gl_model, type: "commit_comment")
    end

    def repository
      url_for_model(gl_model["repository"])
    end

    def user
      url_for_model(gl_model["author"])
    end

    def body
      gl_model["note"]
    end

    def path
      gl_model["path"]
    end

    def position
      gl_model["line"]
    end

    def commit_id
      gl_model["commit"]["id"]
    end

    def created_at
      gl_model["created_at"]
    end
  end
end
