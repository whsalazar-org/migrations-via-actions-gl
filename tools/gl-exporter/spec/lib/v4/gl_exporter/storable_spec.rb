require "spec_helper"

describe GlExporter::Storable, :v4 do
  let(:pseudo_exporter) { PseudoExporter.new(pseudo_model) }

  let(:pseudo_model) do
    PseudoModel.new.tap do |model|
      model["web_url"] = "http://hostname.com/path"
    end
  end

  before(:each) do
    PseudoExporter.include(GlExporter::Storable)
  end

  describe "#store" do
    it "saves a MigratableResource" do
      expect{pseudo_exporter.store("repository", pseudo_model)}
        .to change{GlExporter::MigratableResource.all.length}.by(1)
    end

    it "returns an instance of a MigratableResource" do
      migratable_resource = pseudo_exporter.store("repository", pseudo_model)
      expect(migratable_resource).to be_a(GlExporter::MigratableResource)
    end
  end
end
