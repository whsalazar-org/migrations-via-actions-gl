require 'spec_helper'

describe GlExporter::IssueCommentSerializer, :v3 do
  let(:issue) do
    VCR.use_cassette("v3/gitlab-issue") do
      Gitlab.issue(1169162, 2192031)
    end
  end

  let(:issue_note) do
    VCR.use_cassette("v3/gitlab-issue-note") do
      Gitlab.issue_note(1169162, 2192031, 11735615)
    end
  end

  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  describe "#serialize" do
    subject { described_class.new.serialize(issue_note) }

    before(:each) do
      issue["repository"] = project
      issue_note["issue"] = issue
    end

    it "returns a serialized Issue hash" do
      expected = {
        :type => "issue_comment",
        :url => "https://gitlab.com/Mouse-Hack/hugo-pages/issues/5#note_11735615",
        :issue => "https://gitlab.com/Mouse-Hack/hugo-pages/issues/5",
        :user => "https://gitlab.com/u/jonmagic",
        :body => %{It looks like https://gitlab.com/Mouse-Hack/hugo-pages/merge_requests/1 has already :ship: },
        :formatter => "markdown",
        :created_at => "2016-05-10T22:27:02.519Z"
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end

  context "When given a merge request comment" do
    let(:merge_request) do
      VCR.use_cassette("v3/gitlab-merge-request") do
        Gitlab.merge_request(1169162, 476834)
      end
    end

    let(:merge_request_note) do
      VCR.use_cassette("v3/gitlab-merge-request-note") do
        Gitlab.merge_request_note(1169162, 476834, 11735567)
      end
    end

    describe "#serialize" do
      subject { described_class.new.serialize(merge_request_note) }

      before(:each) do
        merge_request["repository"] = project
        merge_request_note["merge_request"] = merge_request
      end

      it "returns a serialized Pull Request hash" do
        expected = {
          :type => "issue_comment",
          :url => "https://gitlab.com/Mouse-Hack/hugo-pages/merge_requests/2#note_11735567",
          :pull_request => "https://gitlab.com/Mouse-Hack/hugo-pages/merge_requests/2",
          :user => "https://gitlab.com/u/spraints",
          :body => %{asdfasdfasdfasdfasdf},
          :formatter => "markdown",
          :created_at => "2016-05-10T22:20:54.384Z"
        }

        expected.each do |key, value|
          expect(subject[key]).to eq(value)
        end
      end
    end
  end
end
