require "spec_helper"

describe GlExporter::IssueExporter, :v3 do
  let(:issue_exporter) do
    VCR.use_cassette("v3/gl_exporter/issue_exporter") do
      GlExporter::IssueExporter.new(
        issue,
        project_exporter: project_exporter,
      )
    end
  end

  let(:project_exporter) { GlExporter::ProjectExporter.new(project) }

  let(:issue) do
    VCR.use_cassette("v3/gitlab-issue") do
      Gitlab.issue(1169162, 2192031)
    end
  end

  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  describe "#initialize" do
    it "populates issue notes" do
      expect(issue_exporter.issue_notes).to_not be_empty
    end
  end

  describe "#model" do
    it "aliases to the issue" do
      expect(issue_exporter.model).to eq(issue)
    end
  end

  describe "#project" do
    it "returns the project from the project_exporter" do
      expect(issue_exporter.project).to eq(project)
    end
  end

  describe "#created_at" do
    it "returns the timestamp of when the issue was created" do
      expect(issue_exporter.created_at).to eq("2016-05-10T22:20:29.872Z")
    end
  end

  describe "#renumber!" do
    # The example issue has a beginning issue id of `2192031`

    it "changes the id of the attached issue" do
      expect{issue_exporter.renumber!(27)}.to change{issue[Gitlab.issue_id_key]}
        .from(2192031).to(27)
    end

    it "adds a mapping for the renumbering to the project_exporter" do
      expect(project_exporter.rewritten_ids[:issues]).to be_empty
      issue_exporter.renumber!(35)
      expect(project_exporter.rewritten_ids[:issues]).to eq({ 2192031 => 35 })
    end
  end

  describe "rewrite!" do
    it "should call `#rewrite_user_content!`" do
      expect(issue_exporter).to receive(:rewrite_user_content!)
      issue_exporter.rewrite!
    end

    it "should rewrite content for all notes" do
      expect(issue_exporter.issue_notes).to all receive(:rewrite_user_content!)
      issue_exporter.rewrite!
    end
  end

  describe "#export" do
    before(:each) do
      allow_any_instance_of(GlExporter::IssueNoteExporter).to receive(:export)
      allow(issue_exporter).to receive(:extract_attachments)
    end

    it "should serialize the model" do
      expect(issue_exporter).to receive(:serialize)
        .with("issue", issue)
      issue_exporter.export
    end

    it "should extract the attachments from user content" do
      expect(issue_exporter).to receive(:extract_attachments)
        .with("issue", issue)
      issue_exporter.export
    end

    it "should export all the notes" do
      expect(issue_exporter.issue_notes).to all receive(:export)
      issue_exporter.export
    end
  end
end
