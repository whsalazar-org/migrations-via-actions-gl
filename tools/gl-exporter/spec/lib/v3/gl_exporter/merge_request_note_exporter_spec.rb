require "spec_helper"

describe GlExporter::MergeRequestNoteExporter, :v3 do
  let(:merge_request_note_exporter) do
    merge_request_exporter.merge_request_notes.first
  end

  let(:merge_request_exporter) do
    VCR.use_cassette("v3/gl_exporter/merge_request_exporter") do
      GlExporter::MergeRequestExporter.new(
        merge_request,
        project_exporter: project_exporter,
        project_owner: project_owner,
      )
    end
  end

  let(:project_exporter) { GlExporter::ProjectExporter.new(project) }

  let(:merge_request_note) do
    merge_request_note_exporter.merge_request_note
  end

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

  let(:project_owner) do
    VCR.use_cassette("v3/gitlab-export-owner/Mouse-Hack/hugo-pages") do
      Gitlab.group("Mouse-Hack")
    end
  end

  describe "#model" do
    it "aliases to the merge_request_note" do
      expect(merge_request_note_exporter.model).to eq(merge_request_note)
    end
  end

  describe "#merge_request" do
    it "returns the parent merge_request" do
      expect(merge_request_note_exporter.merge_request).to eq(merge_request)
    end
  end

  describe "#current_export" do
    it "returns the current_export from the merge_request_exporter" do
      expect(merge_request_note_exporter.current_export).to eq(project_exporter.current_export)
    end
  end

  describe "#project_exporter" do
    it "returns the project_exporter from the parent merge_request_exporter" do
      expect(merge_request_note_exporter.project_exporter).to eq(project_exporter)
    end
  end

  describe "#export" do
    it "should extract the attachments from user content" do
      expect(merge_request_note_exporter).to receive(:extract_attachments)
        .with("issue_comment", merge_request_note)
      merge_request_note_exporter.export
    end

    it "should serialize the model" do
      expect(merge_request_note_exporter).to receive(:serialize)
        .with("issue_comment", merge_request_note)
      merge_request_note_exporter.export
    end
  end
end
