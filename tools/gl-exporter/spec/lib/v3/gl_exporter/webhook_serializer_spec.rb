require 'spec_helper'

describe GlExporter::WebhookSerializer, :v3 do
  let(:webhook) do
    VCR.use_cassette("v3/gitlab-webhook") do
      Gitlab.webhook(1169162, 50703)
    end
  end

  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  describe "#serialize" do
    subject { described_class.new.serialize(webhook) }

    it "returns a serialized webhook hash" do
      expected = {
        :payload_url => "http://requestb.in/1izuozf1",
        :content_type => "json",
        :event_types => [
          "push",
          "release",
          "issue_comment",
          "pull_request_review_comment",
        ],
        :enable_ssl_verification => true,
        :active => true
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
