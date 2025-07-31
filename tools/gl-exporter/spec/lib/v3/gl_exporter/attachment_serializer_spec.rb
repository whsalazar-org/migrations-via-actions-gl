require 'spec_helper'

describe GlExporter::AttachmentSerializer, :v3 do
  let(:merge_request) do
    VCR.use_cassette("v3/gitlab-merge-request") do
      Gitlab.merge_request(1169162, 476834)
    end
  end

  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  let(:attachment) do
    {
      "type" => "pull_request",
      "model" => merge_request,
      "repository" => project,
      "attach_path" => "/uploads/9ac59438bec5a5e130f6c5c502a34713/image.png",
    }
  end

  describe "#serialize" do
    let(:attachment_serializer) { described_class.new }
    subject { attachment_serializer.serialize(attachment) }

    before(:each) do
      merge_request["repository"] = project
      allow(attachment_serializer).to receive(:content_type).and_return("image/png")
    end

    it "returns a serialized attachment hash" do
      expected = {
          :type => "attachment",
          :url => "https://gitlab.com/Mouse-Hack/hugo-pages/uploads/9ac59438bec5a5e130f6c5c502a34713/image.png",
          :pull_request => "https://gitlab.com/Mouse-Hack/hugo-pages/merge_requests/2",
          :user => "https://gitlab.com/u/spraints",
          :asset_name => "image.png",
          :asset_content_type => "image/png",
          :asset_url => "tarball://root/attachments/uploads/9ac59438bec5a5e130f6c5c502a34713/image.png",
          :created_at => "2016-05-10T22:20:29.649Z"
        }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
