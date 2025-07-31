require "spec_helper"

describe GlExporter::Authorable, :v4 do
  let(:pseudo_exporter) { PseudoExporter.new(pseudo_model) }

  let(:pseudo_model) do
    PseudoModel.new.tap do |model|
      model["web_url"] = "http://hostname.com/path"
    end
  end

  let(:user) { double Hash }

  before(:each) do
    PseudoExporter.include(GlExporter::Authorable)
  end

  describe "#export_user" do
    it "serializes when provided a username" do
      expect(Gitlab).to receive(:user_by_username)
        .with("jonmagic")
        .and_return(user)

      expect(pseudo_exporter).to receive("serialize")
        .with("user", user)

      pseudo_exporter.export_user("jonmagic")
    end

    it "serializes when provided a GitLab user hash" do
      expect(Gitlab).to_not receive(:user_by_username)

      expect(pseudo_exporter).to receive("serialize")
        .with("user", user)

      pseudo_exporter.export_user(user)
    end

    context "for a user that doens't exist", :vcr do
      before { PseudoExporter.include(GlExporter::Writable) }

      it "returns false" do
        expect(pseudo_exporter.export_user("test-for-a-user-that-should-not-exist")).to eq(false)
      end

      it "logs an error" do
        expect(pseudo_exporter.current_export.output_logger).to receive(:error).with(
          "test-for-a-user-that-should-not-exist not found"
        )

        pseudo_exporter.export_user("test-for-a-user-that-should-not-exist")
      end
    end
  end
end
