require "spec_helper"

describe GlExporter::IssueNoteExporter, :v3 do
  let(:issue_note_exporter) do
    issue_exporter.issue_notes.first
  end

  let(:issue_exporter) do
    VCR.use_cassette("v3/gl_exporter/issue_exporter") do
      GlExporter::IssueExporter.new(
        issue,
        project_exporter: project_exporter,
      )
    end
  end

  let(:project_exporter) { GlExporter::ProjectExporter.new(project) }

  let(:issue_note) do
    issue_note_exporter.issue_note
  end

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

  describe "#model" do
    it "aliases to the issue_note" do
      expect(issue_note_exporter.model).to eq(issue_note)
    end
  end

  describe "#issue" do
    it "returns the parent issue" do
      expect(issue_note_exporter.issue).to eq(issue)
    end
  end

  describe "#current_export" do
    it "returns the current_export from the issue_exporter" do
      expect(issue_note_exporter.current_export).to eq(project_exporter.current_export)
    end
  end

  describe "#project_exporter" do
    it "returns the project_exporter from the parent issue_exporter" do
      expect(issue_note_exporter.project_exporter).to eq(project_exporter)
    end
  end

  describe "#export" do
    it "should extract the attachments from user content" do
      expect(issue_note_exporter).to receive(:extract_attachments)
        .with("issue_comment", issue_note)
      issue_note_exporter.export
    end

    it "should serialize the model" do
      expect(issue_note_exporter).to receive(:serialize)
        .with("issue_comment", issue_note)
      issue_note_exporter.export
    end
  end
end
