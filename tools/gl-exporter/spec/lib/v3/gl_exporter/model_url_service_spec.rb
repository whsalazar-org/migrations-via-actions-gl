require 'spec_helper'

describe GlExporter::ModelUrlService, :v3 do
  subject { described_class.new }

  before(:each) do
    allow(Gitlab).to receive(:endpoint).and_return("https://gitlab.com/api/v3")
  end

  let(:user) do
    VCR.use_cassette("v3/gitlab-user") do
      Gitlab.user
    end
  end

  let(:group) do
    VCR.use_cassette("v3/gitlab-group") do
      Gitlab.group("hackmouse")
    end
  end

  let(:label) do
    VCR.use_cassette("v3/gitlab-labels/Mouse-Hack/hugo-pages") do
      Gitlab.labels(project["id"]).first
    end
  end

  let(:tag) do
    VCR.use_cassette("v3/gitlab-release/Mouse-Hack/hugo-pages") do
      Gitlab.tags(project["id"]).detect { |t| t["name"] == "release/with-slash" }
    end
  end

  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  let(:issue) do
    VCR.use_cassette("v3/gitlab-issue") do
      Gitlab.issue(project["id"], 2192031)
    end
  end

  let(:issue_note) do
    VCR.use_cassette("v3/gitlab-issue-note") do
      Gitlab.issue_note(1169162, 2192031, 11735615)
    end
  end

  let(:commit) do
    VCR.use_cassette("v3/gitlab-commit") do
      Gitlab.commit(1169162, "220d5dc2582a49d694c503abdb8cf25bcdd81dce")
    end
  end

  let(:commit_comment) do
    VCR.use_cassette("v3/gitlab-commit_comment") do
      Gitlab.commit_comments(1169162, "220d5dc2582a49d694c503abdb8cf25bcdd81dce").first
    end
  end

  describe "#url_for_model" do
    it "returns a gitlab url for a user" do
      expect(subject.url_for_model(user)).to eq("https://gitlab.com/u/kylemacey")
    end

    it "returns a gitlab url for a group" do
      expect(subject.url_for_model(group)).to eq("https://gitlab.com/groups/hackmouse")
    end

    it "returns a gitlab url for a label" do
      label["repository"] = project
      expect(subject.url_for_model(label, type: "label")).to eq("https://gitlab.com/Mouse-Hack/hugo-pages/labels#/Blocker")
    end

    it "returns a gitlab url for a tag" do
      tag["repository"] = project
      expect(subject.url_for_model(tag, type: "release")).to eq("https://gitlab.com/Mouse-Hack/hugo-pages/tags/release%2Fwith-slash")
    end

    it "returns a gitlab url for an issue" do
      issue["repository"] = project
      expect(subject.url_for_model(issue, type: "issue")).to eq("https://gitlab.com/Mouse-Hack/hugo-pages/issues/5")
    end

    it "returns a gitlab url for an issue note" do
      issue["repository"] = project
      issue_note["issue"] = issue
      expect(subject.url_for_model(issue_note, type: "issue_comment")).to eq("https://gitlab.com/Mouse-Hack/hugo-pages/issues/5#note_11735615")
    end

    it "returns a gitlab url for a milestone" do
      milestone = issue["milestone"]
      milestone["repository"] = project
      expect(subject.url_for_model(milestone, type: "milestone")).to eq("https://gitlab.com/Mouse-Hack/hugo-pages/milestones/1")
    end

    it "returns a gitlab url for an commit comment" do
      commit_comment["repository"] = project
      commit_comment["commit"] = commit
      expect(subject.url_for_model(commit_comment, type: "commit_comment")).to eq("https://gitlab.com/Mouse-Hack/hugo-pages/commit/220d5dc2582a49d694c503abdb8cf25bcdd81dce#note_b9228bf30c71a5bb3313b823eb7c54e9")
    end

    it "does not rewrite other namespaces" do
      model = {"web_url" => "https://gitlab.com/kylemacey/repo-contrib-graph"}
      expect(subject.url_for_model(model)).to_not eq("https://gitlab.com/repo-contrib-graph")
      expect(subject.url_for_model(model)).to eq("https://gitlab.com/kylemacey/repo-contrib-graph")
    end

  end
end
