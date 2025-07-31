require 'spec_helper'

describe GlExporter::MemberSerializer, :v3 do
  let(:member) do
    VCR.use_cassette("v3/gitlab-members") do
      Gitlab.group_members("hackmouse").first
    end
  end
  subject { described_class.new }

  describe "#serialize" do
    subject { described_class.new.serialize(member) }

    it "returns a serialized User hash" do
      expected = {
        :user => "https://gitlab.com/spraints",
        :role => "direct_member",
        :state => "active"
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
