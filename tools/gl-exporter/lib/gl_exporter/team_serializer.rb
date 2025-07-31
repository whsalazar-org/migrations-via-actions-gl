class GlExporter

  # Serializes Teams from data collected by TeamBuilder
  #
  # #### Model Example:
  #
  # ```
  # {
  #   "group"      => "https://gitlab.com/groups/Mouse-Hack",
  #   "permission" => "write",
  #   "members"    => ["https://gitlab.com/u/kylemacey"],
  #   "projects"   => ["https://gitlab.com/Mouse-Hack/hugo-pages"],
  # }
  # ```
  class TeamSerializer < BaseSerializer

    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        "type" => "team",
        "url" => url_for_model(gl_model, type: "team"),
        "organization" => group,
        "name" => name,
        "description" => nil,
        "permissions" => repositories,
        "members" => members,
        "created_at" => Time.now.to_s
      }
    end

    private

    def group
      group = gl_model["group"]
      group[%r{(http.+/groups/)(.+)}, 1] + group[%r{(http.+/groups/)(.+)}, 2].gsub("/", "-")
    end

    def name
      gl_model["name"]
    end

    def repositories
      gl_model["projects"].map do |repository|
        {
          "repository" => convert_repository_url(repository),
          "access" => gl_model["permission"]
        }
      end
    end

    def members
      gl_model["members"].map do |member|
        {
          "user" => member,
          "role" => "member"
        }
      end
    end

    def convert_repository_url(url)
      group = gl_model["group"]
      group_full_path = group[%r{(http.+/groups/)(.+)}, 2]

      url.sub(group_full_path, group_full_path.gsub("/", "-"))
    end
  end
end
