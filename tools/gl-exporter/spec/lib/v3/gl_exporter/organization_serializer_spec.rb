require 'spec_helper'

describe GlExporter::OrganizationSerializer, :v3 do
  let(:group) do
    VCR.use_cassette("v3/gitlab-group") do
      Gitlab.group("hackmouse")
    end
  end
  subject { described_class.new }

  describe "#serialize" do
    subject { described_class.new.serialize(group) }

    it "returns a serialized User hash" do
      expected = {
        :type        => "organization",
        :url         => "https://gitlab.com/groups/hackmouse",
        :login       => "hackmouse",
        :name        => "Hack Mouse",
        :description => "",
        :website     => nil,
        :location    => nil,
        :email       => nil,
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
