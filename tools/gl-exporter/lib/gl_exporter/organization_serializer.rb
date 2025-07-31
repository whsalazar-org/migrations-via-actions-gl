class GlExporter

  # Serializes Organizations from GitLab's Groups
  #
  # #### Model Example:
  #
  # ```
  # {"id"=>488675,
  #  "name"=>"Hack Mouse",
  #  "path"=>"hackmouse",
  #  "ldap_cn"=>nil,
  #  "ldap_access"=>nil,
  #  "description"=>"",
  #  avatar_url"=>nil,
  #  "web_url"=>"https://gitlab.com/groups/hackmouse",
  #  "projects"=>
  #   [...]}
  # ```
  class OrganizationSerializer < BaseSerializer


    # @see GlExporter::BaseSerializer#to_gh_hash  
    def to_gh_hash
      {
        :type        => "organization",
        :url         => url_for_model(gl_model, type: "owner"),
        :login       => gl_model["path"],
        :name        => gl_model["name"],
        :description => gl_model["description"],
        :website     => nil,
        :location    => nil,
        :email       => nil,
        :members     => members
      }
    end

    private

    def members
      gl_model["members"].to_a.map { |member| MemberSerializer.new.serialize(member) }
    end
  end
end
