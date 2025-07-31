class GlExporter

  # Serializes Milestones from GitLab's Milestones
  #
  # #### Model Example:
  #
  # ```
  # {
  #   "id"          => 62677,
  #   "iid"         => 1,
  #   "project_id"  => 1169162,
  #   "title"       => "Prototype",
  #   "description" => "Just get the simplest thing working and out there for folks to try out.",
  #   "state"       => "active",
  #   "created_at"  => "2016-05-10T22:06:45.481Z",
  #   "updated_at"  => "2016-05-10T22:06:45.481Z",
  #   "due_date"    => "2020-04-20"
  # }
  # ```
  #
  # #### Output:
  #
  # ```
  # {
  #   :type        => "milestone",
  #   :url         => url,
  #   :repository  => repository,
  #   :user        => user,
  #   :title       => title,
  #   :description => description,
  #   :state       => state,
  #   :due_on      => due_on,
  #   :created_at  => created_at
  # }
  # ```
  class MilestoneSerializer < BaseSerializer

    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        :type => "milestone",
        :url => url_for_model(gl_model, type: "milestone"),
        :repository => repository,
        :user => user,
        :title => title,
        :description => description,
        :state => state,
        :due_on => due_on,
        :created_at => created_at,
      }
    end

    private

    def repository
      url_for_model(gl_model["repository"])
    end

    def user
      url_for_model(gl_model["user"])
    end

    def title
      gl_model["title"]
    end

    def description
      gl_model["description"]
    end

    def state
      gl_model["state"] == "active" ? "open" : "closed"
    end

    def due_on
      format_timestamp(gl_model["due_date"], true)
    end

    def created_at
      format_timestamp(gl_model["created_at"])
    end
  end
end
