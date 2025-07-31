require "spec_helper"

describe GlExporter::Storage, :v3 do

  subject { described_class.instance }

  describe "#store" do
    it "stores data into a specific collection" do
      subject.store "test", { lorem: "ipsum" }
      expect(subject.data).to eq({"test" => [{ lorem: "ipsum" }] })
    end

    it "stores collection names as strings" do
      subject.store :test, { lorem: "ipsum" }
      expect(subject.data).to eq({"test" => [{ lorem: "ipsum" }] })
    end

    it "appends data as it is stored" do
      subject.store "test", { lorem: "ipsum" }
      subject.store "test", { dolor: "sit" }
      expect(subject.data).to eq({"test" => [{ lorem: "ipsum" }, { dolor: "sit" }] })
    end

    it "stores additional arguments as multiple entries" do
      subject.store "test", { lorem: "ipsum" }, { dolor: "sit" }
      expect(subject.data).to eq({"test" => [{ lorem: "ipsum" }, { dolor: "sit" }] })
    end
  end

  describe "#all" do
    it "returns all data for a collection" do
      subject.store "test", { lorem: "ipsum" }
      expect(subject.all("test")).to eq([{ lorem: "ipsum" }])
    end
  end

  describe "#detect" do
    it "finds the first record that matches a block" do
      subject.store "test", { lorem: "ipsum" }, { dolor: "sit", amet: "consectetur" }
      expect(subject.detect("test") { |record| record[:dolor] == "sit" }).to eq({ dolor: "sit", amet: "consectetur" })
    end
  end

  describe "#purge!" do
    it "deletes all data for a collection" do
      subject.store "test", { lorem: "ipsum" }
      subject.store "other", { dolor: "sit" }
      subject.purge! "test"
      expect(subject.data).to eq({"other" => [{ dolor: "sit" }] })
    end
  end
end
