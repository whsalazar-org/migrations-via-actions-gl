require 'spec_helper'

describe GlExporter::CollaboratorSerializer, :v3 do
  let(:project_team_member) do
    VCR.use_cassette("v3/gitlab-project_team_member/Mouse-Hack/hugo-pages") do
      Gitlab.project_team_members(project["id"]).first
    end
  end

  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  subject { described_class.new }

  describe "#serialize" do
    subject { described_class.new.serialize(project_team_member) }

    it "returns a serialized collaborator hash" do
      expected = {
        :user       => "https://gitlab.com/u/spraints",
        :permission => "maintain",
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
      end
    end
  end
end
