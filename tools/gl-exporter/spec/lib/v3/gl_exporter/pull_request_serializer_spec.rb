require 'spec_helper'

describe GlExporter::PullRequestSerializer, :v3 do
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

  let(:group) do
    VCR.use_cassette("v3/gitlab-export-owner/Mouse-Hack/hugo-pages") do
      Gitlab.group("Mouse-Hack")
    end
  end

  let(:commits) do
    VCR.use_cassette("v3/gitlab-merge-request-commits/Mouse-Hack/hugo-pages") do
      Gitlab.merge_request_commits(1169162, 476834)
    end
  end

  describe "#serialize" do
    let(:pull_request_serializer) { described_class.new }
    subject { pull_request_serializer.serialize(merge_request) }

    before(:each) do
      allow(pull_request_serializer).to receive(:parent_oid).and_return("3a1811f3cb96e9bc426f6ee3544a2cf4f7d5f3fd")
      merge_request["repository"] = project
      merge_request["owner"] = group
      merge_request["commits"] = commits
    end

    it "returns a serialized Issue hash" do
      expected = {
          type: "pull_request",
          url: "https://gitlab.com/Mouse-Hack/hugo-pages/merge_requests/2",
          repository: "https://gitlab.com/Mouse-Hack/hugo-pages",
          user: "https://gitlab.com/u/spraints",
          title: "WIP: this one'll really be about what the branch name says",
          body: %{Please report this. To verizon. Or the NSA.},
          base: {
            ref: "master",
            sha: "3a1811f3cb96e9bc426f6ee3544a2cf4f7d5f3fd",
            user: "https://gitlab.com/groups/Mouse-Hack",
            repo: "https://gitlab.com/Mouse-Hack/hugo-pages"
          },
          head: {
            ref: "omniauth-login",
            sha: "c222af415ecc78c644c139cbf5eb44a25205cbad",
            user: "https://gitlab.com/groups/Mouse-Hack",
            repo: "https://gitlab.com/Mouse-Hack/hugo-pages"
          },
          assignee: "https://gitlab.com/u/spraints",
          milestone: "https://gitlab.com/Mouse-Hack/hugo-pages/milestones/1",
          labels: [
            "https://gitlab.com/Mouse-Hack/hugo-pages/labels#/Blocker",
            "https://gitlab.com/Mouse-Hack/hugo-pages/labels#/Don%27t+Drink+and+Code"
          ],
          merged_at: nil,
          closed_at: nil,
          created_at: "2016-05-10T22:20:29.649Z"
        }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end

    context "with a closed merge request" do
      let(:merge_request) do
        VCR.use_cassette("v3/gitlab-closed-merge-request") do
          Gitlab.merge_request(1169162, 479769)
        end
      end

      it "has a closed_at equal to updated_at" do
        expect(subject[:closed_at]).to eq(merge_request["updated_at"])
      end
    end

    context "with a merged merge request" do
      let(:merge_request) do
        VCR.use_cassette("v3/gitlab-merged-merge-request") do
          Gitlab.merge_request(1169162, 476805)
        end
      end

      it "has a merged_at and closed_at equal to updated_at" do
        expect(subject[:closed_at]).to eq(merge_request["updated_at"])
        expect(subject[:merged_at]).to eq(merge_request["updated_at"])
      end
    end
  end
end
