require "spec_helper"

describe GlExporter::Writable, :v4 do
  let(:pseudo_exporter) { PseudoExporter.new(pseudo_model) }

  let(:pseudo_model) do
    PseudoModel.new.tap do |model|
      model["web_url"] = "http://hostname.com/path"
    end
  end

  let(:archiver) { double GlExporter::ArchiveBuilder }
  let(:serializer) { double GlExporter::RepositorySerializer }

  before(:each) do
    PseudoExporter.include(GlExporter::Writable)
    allow(pseudo_exporter).to receive(:archiver).and_return(archiver)
    allow(GlExporter::RepositorySerializer).to receive(:new).and_return(serializer)
  end

  describe "#serialize" do
    context "when the archiver has written this model before" do
      before(:each) do
        allow(archiver).to receive(:seen?)
          .with("repository", "http://hostname.com/path")
          .and_return(true)
      end

      it "does not write the model" do
        expect(archiver).to_not receive(:write)
        expect(archiver).to_not receive(:seen)
        expect(pseudo_exporter.serialize("repository", pseudo_model)).to eq(false)
      end
    end

    context "when the archiver has not written this model before" do
      before(:each) do
        allow(archiver).to receive(:seen?)
          .with("repository", "http://hostname.com/path")
          .and_return(false)
      end

      it "does writes the model" do
        expect(serializer).to receive(:serialize)
        expect(archiver).to receive(:write)
        expect(archiver).to receive(:seen).with("repository", "http://hostname.com/path")
        expect(pseudo_exporter.serialize("repository", pseudo_model)).to eq(true)
      end
    end

    context "when the model cannot be serialized" do
      it "returns false" do
        expect(pseudo_exporter.serialize("user", nil)).to eq(false)
      end

      it "logs an error" do
        expect(pseudo_exporter.current_export.logger).to receive(:error).with(
          "user:  could not be serialized"
        )

        pseudo_exporter.serialize("user", nil)
      end
    end
  end
end
