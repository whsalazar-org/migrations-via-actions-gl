require 'spec_helper'

describe GlExporter, :v3 do
  let(:exporter) { described_class.new }
  let(:archiver) { double(GlExporter::ArchiveBuilder) }
  let(:project_locker) { double(GlExporter::ProjectLocker) }
  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/kylemacey/Spoon-Knife") do
      Gitlab.project('kylemacey', 'Spoon-Knife')
    end
  end

  before(:each) do
    allow_any_instance_of(GlExporter::ArchiveBuilder).to receive(:repo_clone_url).and_return(File.join(__dir__, "../../../spec/fixtures/repositories/Mouse-Hack/hugo-pages.git"))
  end

  describe "#export_project" do
    context "with project locking" do
      before do
        allow(project_locker).to receive(:lock?).and_return(true)
        allow(project_locker).to receive(:unlock?).and_return(true)
        exporter.instance_variable_set(:@project_locker, project_locker)
        allow_any_instance_of(GlExporter::ProjectExporter).to receive(:export)
      end

      it "locks and unlocks the project" do
        expect(project_locker).to receive(:lock_projects).with([project["id"]])
        expect(project_locker).to receive(:unlock_projects).with([project["id"]])
        exporter.export_project(project)
      end
    end
  end

  describe "#export_from_list" do
    subject do
      VCR.use_cassette("v3/projects-from-list") do
        exporter.send(:export_from_list, "spec/fixtures/export_list.csv")
      end
    end

    before(:each) do
      allow(exporter).to receive(:export_project)
      allow(project_locker).to receive(:lock?).and_return(false)
      allow(project_locker).to receive(:unlock?).and_return(true)
      allow(project_locker).to receive(:locked).and_return(false)
      allow(project_locker).to receive(:unlock_projects).and_return("false")
      allow(project_locker).to receive(:lock_projects).and_return("true")
      exporter.instance_variable_set(:@project_locker, project_locker)
    end

    it "fetches all repositories for the group" do
      # expect(exporter).to receive(:projects_for_group).with('hackmouse')
      expect(exporter).to_not receive(:projects_for_user).with('kylemacey')
      subject
    end

    it "exports all specified projects" do
      projects = [
        ["hackmouse", "example-project"],
        ["hackmouse", "Spoon-Knife"],
        ["kylemacey", "Spoon-Knife"],
      ].map do |namespace, project_name|
        VCR.use_cassette("v3/gitlab-projects/#{namespace}/#{project_name}") do
          Gitlab.project(namespace, project_name)
        end
      end

      allow(exporter).to receive(:projects_from_file).and_return(projects)

      projects.each do |project|
        expect(exporter).to receive(:export_project).with(project)
      end
      expect(project_locker).not_to receive(:lock_projects)
      subject
    end

    it "exports all specified projects with locking" do
      projects = [
        ["hackmouse", "example-project"],
        ["hackmouse", "Spoon-Knife"],
        ["kylemacey", "Spoon-Knife"],
      ].map do |namespace, project_name|
        VCR.use_cassette("v3/gitlab-projects/#{namespace}/#{project_name}") do
          Gitlab.project(namespace, project_name)
        end
      end

      allow(exporter).to receive(:projects_from_file).and_return(projects)
      allow(project_locker).to receive(:lock?).and_return(true)
      allow(Gitlab).to receive(:lock)
      allow(Gitlab).to receive(:unlock)
      projects.each do |project|
        expect(exporter).to receive(:export_project).with(project)
      end
      project_ids = projects.map { |project| project["id"] }
      expect(project_locker).to receive(:lock_projects).with(project_ids)
      subject
    end
  end

  describe "#projects_from_file" do
    subject do
      VCR.use_cassette("v3/projects-from-list") do
        exporter.projects_from_file("spec/fixtures/export_list.csv")
      end
    end

    it "returns an array" do
      expect(subject).to be_an(Array)
    end

    it "contains an array of projects" do
      subject.each do |project|
        expect(project).to be_a(Hash)
      end
    end

    it "returns all specified projects" do
      expect(subject.length).to eq(3)
    end

    context "with a project the exporter cannot find" do
      subject do
        VCR.use_cassette("v3/projects-from-list-faulty") do
          exporter.projects_from_file("spec/fixtures/export_list_faulty.csv")
        end
      end

      it "returns an array" do
        expect(subject).to be_an(Array)
      end

      it "contains an array of projects" do
        subject.each do |project|
          expect(project).to be_a(Hash)
        end
      end

      it "returns all valid projects" do
        expect(subject.length).to eq(3)
      end

      it "does not raise an unhandled error" do
        expect{subject}.to_not raise_error
      end

      it "logs a message to the output" do
        expect(exporter.output_logger).to receive(:error)
        subject
      end

      it "logs the exception to file" do
        expect(exporter.logger).to receive(:error)
        subject
      end
    end
  end

  describe "#export" do
    subject do
      VCR.use_cassette("v3/gl_exporter/complete_export") do
        GlExporter.new(
          namespace: 'Mouse-Hack',
          project: 'hugo-pages',
          output_path: '/tmp/test_export.tar.gz',
        ).export
      end
    end

    it "completes an export without error" do
      expect{subject}.to_not raise_error
    end
  end

  describe "#check_version!" do
    # Minimum version is 8.13.0
    subject do
      exporter.check_version!
    end

    [
      "8.13.0",
      "8.13.0-ee",
      "8.13.0-ce",
      "8.13.5",
      "9.10",
      "10.10",
    ].each do |version|
      it "returns true for version #{version}" do
        allow(Gitlab).to receive(:version).and_return({"version" => version})
        expect(subject).to eq(true)
      end
    end

    [
      "7.8.0",
      "7.8.0-ee",
      "7.8.0-ce",
      "8.8.9",
      "8.9.0",
      "8.9.0-ee",
      "8.9.0-ce",
      "8.9.5",
      "8.9.0-rc2",
      "8.9.0-pre",
      "5.2.0.pre",
      "8.13.0-pre",
    ].each do |version|
      it "raises an error for bad version #{version}" do
        expect(Gitlab).to receive(:version).and_return({"version" => version})
        expect{subject}.to raise_error(GlExporter::BadVersion)
      end
    end
  end
end
