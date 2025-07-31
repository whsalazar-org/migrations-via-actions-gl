class GlExporter
  # Serializes Issues from GitLab's Issues
  #
  # #### Model Example:
  #
  # ```
  # {"id"=>2192031,
  # "iid"=>5,
  # "project_id"=>1169162,
  # "title"=>"Don't have a GitHub account",
  # "description"=>
  #  "I appreciate wanting to support logging in with GitHub but I don't have a GitHub account and cannot legally sign up for one in my country due to my age unless I get my parents permission. See https://gitlab.com/Mouse-Hack/hugo-pages/issues/1 for more details.",
  # "state"=>"opened",
  # "created_at"=>"2016-05-10T22:20:29.872Z",
  # "updated_at"=>"2016-05-10T23:35:20.403Z",
  # "labels"=>["Blocker", "Bug"],
  # "milestone"=>
  #  {"id"=>62677,
  #   "iid"=>1,
  #   "project_id"=>1169162,
  #   "title"=>"Prototype",
  #   "description"=>"Just get the simplest thing working and out there for folks to try out.",
  #   "state"=>"active",
  #   "created_at"=>"2016-05-10T22:06:45.481Z",
  #   "updated_at"=>"2016-05-10T22:06:45.481Z",
  #   "due_date"=>"2020-04-20"},
  # "assignee"=>{"name"=>"Kyle Macey",
  #  "username"=>"kylemacey",
  #  "id"=>414903,
  #  "state"=>"active",
  #  "avatar_url"=>"https://secure.gravatar.com/avatar/e7bc3ce1dbb0fcaa9bb00bf10628526e?s=80&d=identicon",
  #  "web_url"=>"https://gitlab.com/u/kylemacey"},
  # "author"=>
  #  {"name"=>"Jon Magic",
  #   "username"=>"jonmagic",
  #   "id"=>529946,
  #   "state"=>"active",
  #   "avatar_url"=>"https://secure.gravatar.com/avatar/7064ad438246a02809c85bcd92cb5f3f?s=80&d=identicon",
  #   "web_url"=>"https://gitlab.com/u/jonmagic"},
  # "subscribed"=>false}
  # ```
  class IssueSerializer < BaseSerializer


    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        :type       => "issue",
        :url        => url_for_model(gl_model, type: "issue"),
        :repository => repository,
        :user       => user,
        :title      => title,
        :body       => body,
        :assignee   => assignee,
        :milestone  => milestone,
        :labels     => labels,
        :closed_at  => closed_at,
        :created_at => created_at
      }
    end

    private

    def repository
      url_for_model(gl_model["repository"])
    end

    def user
      gl_model["author"]["web_url"]
    end

    def title
      gl_model["title"]
    end

    def body
      gl_model["description"]
    end

    def assignee
      return unless gl_model["assignee"]
      gl_model["assignee"]["web_url"]
    end

    def milestone
      return unless gl_model["milestone"]
      gl_model["milestone"]["repository"] = gl_model["repository"]
      url_for_model(gl_model["milestone"], type: "milestone")
    end

    def labels
      gl_model["labels"].map do |label_name|
        label = {
          "name"       => label_name,
          "repository" => gl_model["repository"],
        }
        url_for_model(label, type: "label")
      end
    end

    def closed_at
      if gl_model["state"] == "closed"
        gl_model["updated_at"]
      end
    end

    def created_at
      gl_model["created_at"]
    end
  end
end
