require 'spec_helper'

describe GlExporter::ReleaseSerializer, :v4 do
  let(:tag) do
    VCR.use_cassette("v4/gitlab-tag") do
      Gitlab.tag(1169162, "end-of-sinatra")
    end
  end

  let(:project) do
    VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  let(:user) do
    VCR.use_cassette("v4/gitlab-user") do
      Gitlab.user
    end
  end

  describe "#serialize" do
    subject { described_class.new.serialize(tag) }

    before(:each) {
      tag["repository"] = project
      tag["user"] = user
    }

    it "returns a serialized release hash" do
      expected = {
        :type             => "release",
        :url              => "https://gitlab.com/Mouse-Hack/hugo-pages/tags/end-of-sinatra",
        :repository       => "https://gitlab.com/Mouse-Hack/hugo-pages",
        :user             => "https://gitlab.com/kylemacey",
        :name             => "end-of-sinatra",
        :tag_name         => "end-of-sinatra",
        :body             => "This is the end of sinatra release.![IMG_1708](/uploads/78cf9f363723223e09785f812c732500/IMG_1708.jpg)",
        :state            => "published",
        :pending_tag      => "end-of-sinatra",
        :prerelease       => false,
        :target_commitish => "master",
        :release_assets   => [],
        :published_at     => "2016-05-10T06:06:10.000-07:00",
        :created_at       => "2016-05-10T06:06:10.000-07:00"
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
