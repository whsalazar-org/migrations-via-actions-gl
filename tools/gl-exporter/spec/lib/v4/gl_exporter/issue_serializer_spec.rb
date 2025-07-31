require 'spec_helper'

describe GlExporter::IssueSerializer, :v4 do
  let(:issue) do
    VCR.use_cassette("v4/gitlab-issue") do
      Gitlab.issue(1169162, 5)
    end
  end

  let(:project) do
    VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  describe "#serialize" do
    subject { described_class.new.serialize(issue) }

    before(:each) do
      issue["repository"] = project
    end

    it "returns a serialized Issue hash" do
      expected = {
          :type       => "issue",
          :url        => "https://gitlab.com/Mouse-Hack/hugo-pages/issues/5",
          :repository => "https://gitlab.com/Mouse-Hack/hugo-pages",
          :user       => "https://gitlab.com/jonmagic",
          :title      => "Don't have a GitHub account",
          :body       => %{I appreciate wanting to support logging in with GitHub but I don't have a GitHub account and cannot legally sign up for one in my country due to my age unless I get my parents permission. See https://gitlab.com/Mouse-Hack/hugo-pages/issues/1 for more details.},
          :assignee   => "https://gitlab.com/kylemacey",
          :milestone  => "https://gitlab.com/Mouse-Hack/hugo-pages/milestones/1",
          :labels     => [
            "https://gitlab.com/Mouse-Hack/hugo-pages/labels#/Blocker",
            "https://gitlab.com/Mouse-Hack/hugo-pages/labels#/Bug"
          ],
          :closed_at  => nil,
          :created_at => "2016-05-10T22:20:29.872Z"
        }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end

    context "with a closed issue" do
      let(:issue) do
        VCR.use_cassette("v4/gitlab-closed-issue") do
          Gitlab.issue(1169162, 1)
        end
      end

      it "has a closed_at equal to updated_at" do
        expect(subject[:closed_at]).to eq(issue["updated_at"])
      end
    end
  end
end
