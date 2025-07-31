require "spec_helper"

describe GlExporter::MergeRequestExporter, :v4 do
  let(:project_exporter) { GlExporter::ProjectExporter.new(project) }

  let(:project) do
    VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  let(:project_owner) do
    VCR.use_cassette("v4/gitlab-export-owner/Mouse-Hack/hugo-pages") do
      Gitlab.group("Mouse-Hack")
    end
  end

  let(:merge_request) do
    VCR.use_cassette("v4/gitlab-merge-request") do
      Gitlab.merge_request(1169162, 2)
    end
  end

  let(:merge_request_exporter) do
    VCR.use_cassette("v4/gl_exporter/merge_request_exporter", allow_playback_repeats: true) do
      GlExporter::MergeRequestExporter.new(
        merge_request,
        project_exporter: project_exporter,
        project_owner: project_owner,
      )
    end
  end

  let(:merge_request_without_commits) do
    VCR.use_cassette("v4/gitlab-merge-request-without-commits") do
      Gitlab.merge_request(1169162, 10)
    end
  end

  let(:merge_request_exporter_without_commits) do
    VCR.use_cassette("v4/gl_exporter/merge_request_exporter_without_commits", allow_playback_repeats: true) do
      GlExporter::MergeRequestExporter.new(
        merge_request_without_commits,
        project_exporter: project_exporter,
        project_owner: project_owner,
      )
    end
  end

  describe "#initialize" do
    it "populates merge_request notes" do
      expect(merge_request_exporter.merge_request_notes).to_not be_empty
    end

    it "populates the commits for the merge request" do
      expect(merge_request_exporter.merge_request["commits"]).to_not be_empty
    end
  end

  describe "#model" do
    it "aliases to the merge_request" do
      expect(merge_request_exporter.model).to eq(merge_request)
    end
  end

  describe "#project" do
    it "returns the project from the project_exporter" do
      expect(merge_request_exporter.project).to eq(project)
    end
  end

  describe "#created_at" do
    it "returns the timestamp of when the merge_request was created" do
      expect(merge_request_exporter.created_at).to eq("2016-05-10T22:20:29.649Z")
    end
  end

  describe "#renumber!" do
    # The example merge_request has a beginning merge_request id of `2`

    it "changes the id of the attached merge_request" do
      expect{merge_request_exporter.renumber!(27)}.to change{merge_request[Gitlab.issue_id_key]}
        .from(2).to(27)
    end

    it "adds a mapping for the renumbering to the project_exporter" do
      expect(project_exporter.rewritten_ids[:merge_requests]).to be_empty
      merge_request_exporter.renumber!(35)
      expect(project_exporter.rewritten_ids[:merge_requests]).to eq({ 2 => 35 })
    end
  end

  describe "rewrite!" do
    it "should call `#rewrite_user_content!`" do
      expect(merge_request_exporter).to receive(:rewrite_user_content!)
      merge_request_exporter.rewrite!
    end

    it "should rewrite content for all notes" do
      expect(merge_request_exporter.merge_request_notes).to all receive(:rewrite_user_content!)
      merge_request_exporter.rewrite!
    end
  end

  describe "#export" do
    before(:each) do
      allow_any_instance_of(GlExporter::PullRequestSerializer)
        .to receive(:parent_oid)
        .and_return("3a1811f3cb96e9bc426f6ee3544a2cf4f7d5f3fd")
      allow_any_instance_of(GlExporter::MergeRequestNoteExporter).to receive(:export)
      allow(merge_request_exporter).to receive(:extract_attachments)
    end

    it "should serialize the model" do
      expect(merge_request_exporter).to receive(:serialize)
        .with("pull_request", merge_request)
      merge_request_exporter.export
    end

    it "should extract the attachments from user content" do
      expect(merge_request_exporter).to receive(:extract_attachments)
        .with("pull_request", merge_request)
      merge_request_exporter.export
    end

    it "should export all the notes" do
      expect(merge_request_exporter.merge_request_notes).to all receive(:export)
      merge_request_exporter.export
    end

    it "should export merge requests with no commits as issues" do
      expect(merge_request_exporter_without_commits).to receive(:serialize)
        .with("issue", merge_request_without_commits)
      merge_request_exporter_without_commits.export
    end
  end

  context "Rugged cannot find a reference" do
    before(:each) do
      allow_any_instance_of(GlExporter::PullRequestSerializer)
        .to receive(:base_sha)
        .and_raise(Rugged::OdbError.new)
      allow_any_instance_of(GlExporter::MergeRequestNoteExporter).to receive(:export)
      allow(merge_request_exporter).to receive(:extract_attachments)
    end

    it "does not raise an unhandled error" do
      expect{merge_request_exporter.export}.to_not raise_error
    end

    it "serializes the merge request as an issue" do
      expect(merge_request_exporter).to receive(:serialize)
        .with("pull_request", merge_request).and_call_original
      expect(merge_request_exporter).to receive(:serialize)
        .with("issue", merge_request)
      merge_request_exporter.export
    end

    it "extracts attachments from the merge request as an issue" do
      expect(merge_request_exporter).to receive(:extract_attachments)
        .with("issue", merge_request)
      merge_request_exporter.export
    end

    it "exports all the notes as issue notes" do
      expect(merge_request_exporter.merge_request_notes)
        .to all receive(:export_as_issue_note)
      merge_request_exporter.export
    end

    it "logs a message to the output" do
      expect(project_exporter.current_export.output_logger).to receive(:warn)
      merge_request_exporter.export
    end

    it "logs the exception to file" do
      expect(project_exporter.current_export.logger).to receive(:error)
      merge_request_exporter.export
    end
  end
end
