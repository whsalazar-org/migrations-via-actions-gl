require 'spec_helper'

describe GlExporter::LabelSerializer, :v3 do
  let(:label) do
    VCR.use_cassette("v3/gitlab-labels/Mouse-Hack/hugo-pages") do
      Gitlab.labels(project["id"]).first
    end
  end

  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  subject { described_class.new }

  before(:each) do
    label["repository"] = project
  end

  describe "#serialize" do
    subject { described_class.new.serialize(label) }

    it "returns a serialized Repository hash" do
      expected = {
        :type => 'label',
        :url => "https://gitlab.com/Mouse-Hack/hugo-pages/labels#/Blocker",
        :name => 'Blocker',
        :color => 'a295d6'
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
      end
    end
  end
end
