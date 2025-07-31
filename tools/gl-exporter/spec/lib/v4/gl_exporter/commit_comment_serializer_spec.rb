require 'spec_helper'

describe GlExporter::CommitCommentSerializer, :v4 do
  let(:commit) do
    VCR.use_cassette("v4/gitlab-commit") do
      Gitlab.commit(1169162, "220d5dc2582a49d694c503abdb8cf25bcdd81dce")
    end
  end

  let(:commit_comment) do
    VCR.use_cassette("v4/gitlab-commit_comment") do
      Gitlab.commit_comments(1169162, "220d5dc2582a49d694c503abdb8cf25bcdd81dce").first
    end
  end

  let(:project) do
    VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  describe "#serialize" do
    subject { described_class.new.serialize(commit_comment) }

    before(:each) do
      commit_comment["repository"] = project
      commit_comment["commit"] = commit
    end

    it "returns a serialized Issue hash" do
      expected = {
        :type       => "commit_comment",
        :url        => "https://gitlab.com/Mouse-Hack/hugo-pages/commit/220d5dc2582a49d694c503abdb8cf25bcdd81dce#note_10b658e747cf610dd8519662f1b0a763",
        :repository => "https://gitlab.com/Mouse-Hack/hugo-pages",
        :user       => "https://gitlab.com/lizzhale",
        :body       => "is this necessary?\r\n\r\n[testFile.txt](/uploads/af7fcacfc5d69fdcf63a8f04048a106f/testFile.txt)\r\n\r\n\r\n\r\n",
        :formatter  => "markdown",
        :path       => "Brewfile",
        :position   => 5,
        :commit_id  => "220d5dc2582a49d694c503abdb8cf25bcdd81dce",
        :created_at => "2016-05-10T22:23:50.501Z"
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
