class GlExporter

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

  # Serializes Collaborators from GitLab's Project Team Members
  #
  # #### Model Example:
  #
  # ```
  # {"name"=>"Matt",
  #   "username"=>"spraints",
  #   "id"=>142189,
  #   "state"=>"active",
  #   "avatar_url"=>"https://secure.gravatar.com/avatar/0bf208eebdab7c5d16152f70a1ee837f?s=80&d=identicon",
  #   "web_url"=>"https://gitlab.com/u/spraints",
  #   "access_level"=>40}
  # ```
  class CollaboratorSerializer < BaseSerializer

    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        :user       => user,
        :permission => permission,
      }
    end

    private

    def user
      url_for_model(gl_model)
    end

    def permission
      PERMISSION_MAP[gl_model["access_level"]]
    end
  end
end
