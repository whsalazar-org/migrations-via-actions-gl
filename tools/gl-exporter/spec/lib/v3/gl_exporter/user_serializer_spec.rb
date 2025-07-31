require 'spec_helper'

describe GlExporter::UserSerializer, :v3 do
  let(:user) do
    VCR.use_cassette("v3/gitlab-user") do
      Gitlab.user
    end
  end
  subject { described_class.new }

  describe "#serialize" do
    subject { described_class.new.serialize(user) }

    it "returns a serialized User hash" do
      expected = {
        :type => "user",
        :url => "https://gitlab.com/u/kylemacey",
        :login => "kylemacey",
        :name => "Kyle Macey",
        :company => nil,
        :website => "",
        :location => nil,
        :emails => [{"address" => "shout@kylemacey.com", "primary" => true}],
        :created_at => "2016-02-16T16:36:31.355Z"
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
