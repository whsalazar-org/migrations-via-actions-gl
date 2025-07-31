require "spec_helper"

describe GlExporter::ProjectLocker, :v3 do
  let(:project) do
    VCR.use_cassette("v3/gitlab-projects-id/kylemacey/Spoon-Knife") do
      Gitlab.project_by_id(1123699)
    end
  end

  before do
    allow(Gitlab).to receive(:project_by_id).with(project["id"]).and_return(project)
  end

  describe "#lock_projects" do
    context "with project locking enabled" do
      subject(:project_locker) { described_class.new(true) }

      it "locks the project" do
        expect(Gitlab).to receive(:lock).with(project["id"])
        project_locker.lock_projects([project["id"]])
      end

      context "when the project is already locked" do
        before do
          project["archived"] = true
        end

        it "does not attempt to lock the project" do
          expect(Gitlab).to_not receive(:lock).with(project["id"])
          project_locker.lock_projects([project["id"]])
        end
      end
    end
  end
end
