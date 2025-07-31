class GlExporter

  # Serializes Organization Members from GitLab's Group Members
  #
  # #### Model Example:
  #
  # ```
  # {"name"=>"Kyle Macey",
  #  "username"=>"kylemacey",
  #  "id"=>414903,
  #  "state"=>"active",
  #  "avatar_url"=>"https://secure.gravatar.com/avatar/e7bc3ce1dbb0fcaa9bb00bf10628526e?s=80&d=identicon",
  #  "web_url"=>"https://gitlab.com/u/kylemacey",
  #  "access_level"=>50}
  # ```
  class MemberSerializer < BaseSerializer

    # Which GitLab access levels are equivalent to GitHub's Organization Owner
    # role. 
    OWNER_ROLES = [50]

    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        :user => url_for_model(gl_model),
        :role => role,
        :state => gl_model["state"]
      }
    end

    private

    def role
      OWNER_ROLES.include?(gl_model["access_level"]) ? "admin" : "direct_member"
    end
  end
end
