require "spec_helper"

describe GlExporter::Attachable, :v3 do
  let(:pseudo_exporter) { PseudoExporter.new(pseudo_model) }

  let(:pseudo_model) do
    PseudoModel.new.tap do |model|
      model["note"] = body_content
      model["iid"] = 55
      model["repository"] = {
        "web_url" => "https://gitlab.com/Mouse-Hack/hugo-pages"
      }
    end
  end

  let(:body_content) do <<-'EOS'
Here is my issue

![image](/uploads/4c34b72a41b3e1b2f9a97fd0c2e50d82/image.png)

[pdf-sample.pdf](/uploads/aca2cc60c183e113481adbdd167aa9fe/pdf-sample.pdf)

![image](/uploads/6323ffc765d5e4ae138992687096851b/image.png) for **manually added deal**** in the Deal Management (***"SourceType":6***,"SourceName":"<script>alert(\"This is XSS vulnerability\")</script>","**ManualDealId****":"<script>alert(\"This is XSS vulnerability\")</script>"
EOS
  end

  let(:project) { double Hash }

  let(:archiver) { double GlExporter::ArchiveBuilder }

  before(:each) do
    PseudoExporter.include(GlExporter::Attachable)
    allow(pseudo_exporter).to receive(:archiver).and_return(archiver)
    allow(pseudo_exporter).to receive(:project).and_return(project)
    allow(project).to receive(:[]).with("web_url").and_return("http://hostname.com/path")
    allow(project).to receive(:[]).with("namespace").and_return("path")
    allow(archiver).to receive(:save_attachment).and_return(true)
    allow(pseudo_exporter).to receive(:serialize)
  end

  describe "#extract_attachments" do
    it "extracts images from the text" do
      expect(pseudo_exporter).to receive(:serialize).with(
        "attachment",
        {
          "type"        => "issue",
          "model"       => pseudo_model,
          "repository"  => project,
          "attach_path" => "/uploads/4c34b72a41b3e1b2f9a97fd0c2e50d82/image.png"
        }
      )

      pseudo_exporter.extract_attachments("issue", pseudo_model)
    end

    it "extracts attachments from the text" do
      expect(pseudo_exporter).to receive(:serialize).with(
        "attachment",
        {
          "type"        => "issue",
          "model"       => pseudo_model,
          "repository"  => project,
          "attach_path" => "/uploads/aca2cc60c183e113481adbdd167aa9fe/pdf-sample.pdf"
        }
      )

      pseudo_exporter.extract_attachments("issue", pseudo_model)
    end

    it "extracts inline attachments from the text" do
      expect(pseudo_exporter).to receive(:serialize).with(
        "attachment",
        {
          "type"        => "issue",
          "model"       => pseudo_model,
          "repository"  => project,
          "attach_path" => "/uploads/6323ffc765d5e4ae138992687096851b/image.png"
        }
      )

      pseudo_exporter.extract_attachments("issue", pseudo_model)
    end

    context "with erroneous atatchments" do
      before do
        allow(archiver).to receive(:save_attachment).and_return(false)
      end

      it "will not serialize attachments" do
        expect(pseudo_exporter).to_not receive(:serialize)

        pseudo_exporter.extract_attachments("issue", pseudo_model)
      end
    end
  end
end
