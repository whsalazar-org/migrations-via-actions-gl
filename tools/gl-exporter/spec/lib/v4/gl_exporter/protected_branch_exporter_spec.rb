require "spec_helper"

describe GlExporter::ProtectedBranchExporter, :v4 do
  let(:protected_branch_exporter) do
    VCR.use_cassette("v4/gl_exporter/protected_branch_exporter") do
      GlExporter::ProtectedBranchExporter.new(
        protected_branch,
        project_exporter: project_exporter,
      )
    end
  end

  let(:project_exporter) { GlExporter::ProjectExporter.new(project) }

  let(:protected_branch) do
    VCR.use_cassette("v4/gitlab-branch") do
      Gitlab.branch(1169162, "master")
    end
  end

  let(:project) do
    VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  describe "#model" do
    it "aliases to the protected_branch" do
      expect(protected_branch_exporter.model).to eq(protected_branch)
    end
  end

  describe "#project" do
    it "returns the project from the project_exporter" do
      expect(protected_branch_exporter.project).to eq(project)
    end
  end

  describe "#export" do
    it "should serialize the model" do
      expect(protected_branch_exporter).to receive(:serialize).with(
        "protected_branch", protected_branch
      )
      protected_branch_exporter.export
    end
  end
end
