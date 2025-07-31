require "spec_helper"

describe GlExporter::MigratableResource, :v3 do
  describe "#all" do
    it "returns all MigratableResource instances" do
      described_class.create("issue", {})
      described_class.create("pull_request", {})

      expect(described_class.all.size).to eq(2)
    end
  end
end
