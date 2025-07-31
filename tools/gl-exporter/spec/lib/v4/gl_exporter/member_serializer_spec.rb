require 'spec_helper'

describe GlExporter::MemberSerializer, :v4 do
  let(:member) do
    VCR.use_cassette("v4/gitlab-members/all") do
      Gitlab.group_members("Mouse-Hack").first
    end
  end
  subject { described_class.new }

  describe "#serialize" do
    subject { described_class.new.serialize(member) }

    it "returns a serialized User hash" do
      expected = {
        :user => "https://gitlab.com/spraints",
        :role => "admin",
        :state => "active"
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
