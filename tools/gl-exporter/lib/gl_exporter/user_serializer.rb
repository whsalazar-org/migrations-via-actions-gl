class GlExporter

  # Serializes Users from GitLab's Users
  #
  # #### Model Example:
  #
  # ```
  # {
  #   "name"=>"Kyle Macey",
  #   "username"=>"kylemacey",
  #   "id"=>414903,
  #   "state"=>"active",
  #   "avatar_url"=>"https://secure.gravatar.com/avatar/e7bc3ce1dbb0fcaa9bb00bf10628526e?s=80&d=identicon",
  #   "web_url"=>"https://gitlab.com/u/kylemacey",
  #   "created_at"=>"2016-02-16T16:36:31.355Z",
  #   "is_admin"=>false,
  #   "bio"=>nil,
  #   "skype"=>"",
  #   "linkedin"=>"",
  #   "twitter"=>"",
  #   "website_url"=>"",
  #   "email"=>"shout@kylemacey.com",
  #   "theme_id"=>2,
  #   "color_scheme_id"=>1,
  #   "projects_limit"=>100000,
  #   "current_sign_in_at"=>"2016-02-17T21:53:08.606Z",
  #   "identities"=>[],
  #   "can_create_group"=>true,
  #   "can_create_project"=>true,
  #   "two_factor_enabled"=>false,
  #   "private_token"=>"..."}
  # ```
  class UserSerializer < BaseSerializer


    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        :type       => "user",
        :url        => url_for_model(gl_model),
        :login      => gl_model["username"],
        :name       => gl_model["name"],
        :company    => nil,
        :website    => gl_model["website_url"],
        :location   => nil,
        :emails     => emails,
        :created_at => gl_model["created_at"]
      }
    end

    private

    def emails
      if email = gl_model["email"]
        [{"address" => email, "primary" => true}]
      else
        []
      end
    end

  end
end
