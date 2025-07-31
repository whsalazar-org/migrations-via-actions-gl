require "spec_helper"

describe GlExporter::UserContentRewritable, :v3 do
  let(:pseudo_exporter) { PseudoExporter.new(pseudo_model) }

  let(:pseudo_model) do
    PseudoModel.new.tap do |model|
      model["note"] = body_content
    end
  end

  let(:body_content) { "lorem ipsum" }

  let(:project_exporter) { GlExporter::ProjectExporter.new(project) }

  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  before(:each) do
    PseudoExporter.include(GlExporter::UserContentRewritable)
    allow(pseudo_exporter).to receive(:project_exporter).and_return(project_exporter)
  end

  describe "#rewrite_user_content!" do
    it "detects the correct body key" do
      expect(pseudo_exporter).to receive(:rewrite_numeric_mentions)
        .with("note")
      pseudo_exporter.rewrite_user_content!
    end
  end

  describe "#rewrite_numeric_mentions" do
    let(:body_content) do
      "This is a merge: !1001, issue: #123, notthis!321 or#585this "
    end

    it "detects merge request and issue mentions" do
      expect(pseudo_exporter).to receive(:translate_id).with("!", "1001")
      expect(pseudo_exporter).to receive(:translate_id).with("#", "123")
      expect(pseudo_exporter).to_not receive(:translate_id).with("!", "321")
      expect(pseudo_exporter).to_not receive(:translate_id).with("#", "585")
      pseudo_exporter.rewrite_numeric_mentions("note")
    end
  end

  describe "#translate_id" do
    before(:each) do
      project_exporter.rewritten_ids[:merge_requests] = {
        10 => 30,
        20 => 1,
        21 => 2,
        22 => 5,
      }
      project_exporter.rewritten_ids[:issues] = {
        10 => 20,
        18 => 3,
        19 => 4,
        23 => 6,
      }
    end

    it "translates merge request ids" do
      expect(pseudo_exporter.translate_id("!", "10")).to eq("30")
      expect(pseudo_exporter.translate_id("!", "20")).to eq("1")
      expect(pseudo_exporter.translate_id("!", "21")).to eq("2")
      expect(pseudo_exporter.translate_id("!", "22")).to eq("5")
      expect(pseudo_exporter.translate_id("!", "34")).to eq("34")
    end

    it "translates issue ids" do
      expect(pseudo_exporter.translate_id("#", "10")).to eq("20")
      expect(pseudo_exporter.translate_id("#", "18")).to eq("3")
      expect(pseudo_exporter.translate_id("#", "19")).to eq("4")
      expect(pseudo_exporter.translate_id("#", "23")).to eq("6")
      expect(pseudo_exporter.translate_id("#", "34")).to eq("34")
    end
  end
end
