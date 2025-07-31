require "spec_helper"

describe GlExporter::CommitCommentExporter, :v4 do
  let(:commit_comment_exporter) do
    VCR.use_cassette("v4/gl_exporter/commit_comment_exporter") do
      GlExporter::CommitCommentExporter.new(
        commit,
        commit_comment,
        project_exporter: project_exporter,
      )
    end
  end

  let(:project_exporter) { GlExporter::ProjectExporter.new(project) }

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

  describe "#model" do
    it "aliases to the commit comment" do
      expect(commit_comment_exporter.model).to eq(commit_comment)
    end
  end

  describe "#project" do
    it "returns the project from the project_exporter" do
      expect(commit_comment_exporter.project).to eq(project)
    end
  end

  describe "#created_at" do
    it "returns the timestamp of when the commit comment was created" do
      expect(commit_comment_exporter.created_at).to eq("2016-05-10T22:23:50.501Z")
    end
  end

  describe "rewrite!" do
    it "should call `#rewrite_user_content!`" do
      expect(commit_comment_exporter).to receive(:rewrite_user_content!)
      commit_comment_exporter.rewrite!
    end
  end

  describe "#export" do
    it "should serialize the model and extract attachments" do
      expect(commit_comment_exporter).to receive(:extract_attachments)
        .with("commit_comment", commit_comment)
      expect(commit_comment_exporter).to receive(:serialize)
        .with("commit_comment", commit_comment)
      commit_comment_exporter.export
    end
  end
end
