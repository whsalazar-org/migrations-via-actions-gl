require "spec_helper"

describe Gitlab::UrlBuilder, :v3 do
  describe "#initialize" do
    it "properly appends absolute paths to the api path" do
      builder = described_class.new(
        "/absolute/path"
      )
      expect(builder.to_s).to eq("https://gitlab.com/api/v3/absolute/path")
    end

    it "can specify records per page" do
      builder = described_class.new(
        'some/path', params: {
          per_page: 13,
        }
      )
      expect(builder.to_s).to eq("https://gitlab.com/api/v3/some/path?per_page=13")
    end

    it "can specify which page to fetch" do
      builder = described_class.new(
        'some/path', params: {
          page: 3,
        }
      )
      expect(builder.to_s).to eq("https://gitlab.com/api/v3/some/path?page=3")
    end

    it "can specify records per page and which page to fetch" do
      builder = described_class.new(
        'some/path', params: {
          per_page: 13,
          page: 3,
        }
      )
      expect(builder.to_s).to eq("https://gitlab.com/api/v3/some/path?per_page=13&page=3")
    end
  end
end
