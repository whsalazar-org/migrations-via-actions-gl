class GlExporter

  # Serializes Releases from GitLab's Tags
  #
  # #### Model Example:
  #
  # ```
  #    [{"name"=>"v1.0.0",
  #  "message"=>"version 1.0.0 is shipping",
  #  "commit"=>
  #   {"id"=>"3a1811f3cb96e9bc426f6ee3544a2cf4f7d5f3fd",
  #    "message"=>
  #     "Merge branch 'omniauth-login' into 'master'\r\n\r\nNeed some hugo, more than #4\r\n\r\nBig changes\r\n\r\nSee merge request !1",
  #    "parent_ids"=>
  #     ["a7291a05bb99bb755cdcaceb76b4f3d7f24837d5",
  #      "220d5dc2582a49d694c503abdb8cf25bcdd81dce"],
  #    "authored_date"=>"2016-05-10T22:15:31.000+00:00",
  #    "author_name"=>"Matt",
  #    "author_email"=>"spraints@gmail.com",
  #    "committed_date"=>"2016-05-10T22:15:31.000+00:00",
  #    "committer_name"=>"Matt",
  #    "committer_email"=>"spraints@gmail.com"},
  #  "release"=>nil},
  # {"name"=>"end-of-sinatra",
  #  "message"=>nil,
  #  "commit"=>
  #   {"id"=>"1490680b9a193ff188eb0dff7281b29869c62937",
  #    "message"=>"Choose my scopes\n",
  #    "parent_ids"=>["27c44637e863f719c071d961ab42a6afc041e034"],
  #    "authored_date"=>"2016-05-10T06:06:10.000-07:00",
  #    "author_name"=>"Matt Burke",
  #    "author_email"=>"spraints@gmail.com",
  #    "committed_date"=>"2016-05-10T06:06:10.000-07:00",
  #    "committer_name"=>"Matt Burke",
  #    "committer_email"=>"spraints@gmail.com"},
  #  "release"=>
  #   {"tag_name"=>"end-of-sinatra",
  #    "description"=>
  #     "This is the end of sinatra release.![IMG_1708](/uploads/78cf9f363723223e09785f812c732500/IMG_1708.jpg)"}}]
  # ```
  # @todo only create a hash for release tags
  class ReleaseSerializer < BaseSerializer

    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
     {
       :type             => "release",
       :url              => url_for_model(gl_model, type: "release"),
       :repository       => repository,
       :user             => user,
       :name             => name,
       :tag_name         => tag_name,
       :body             => body,
       :state            => "published",
       :pending_tag      => tag_name,
       :prerelease       => false,
       :target_commitish => "master",
       :release_assets   => [],
       :published_at     => authored_date,
       :created_at       => authored_date
     }
    end

    private

    def repository
      url_for_model(gl_model["repository"])
    end

    def user
      url_for_model(gl_model["user"])
    end

    def name
      gl_model["name"]
    end

    def tag_name
      gl_model["release"]["tag_name"]
    end

    def body
     gl_model["release"]["description"]
    end

    def authored_date
      gl_model["commit"]["authored_date"]
    end
  end
end
