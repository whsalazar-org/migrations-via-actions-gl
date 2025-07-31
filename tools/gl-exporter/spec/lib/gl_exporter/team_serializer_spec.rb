require 'spec_helper'

describe GlExporter::TeamSerializer do
  let(:team) do
    {
      "group"      => "https://gitlab.com/groups/Mouse-Hack",
      "permission" => "write",
      "members"    => ["https://gitlab.com/u/kylemacey"],
      "projects"   => ["https://gitlab.com/Mouse-Hack/hugo-pages"],
      "name"       => "Mouse-Hack Write Access",
    }
  end

  let(:team_in_subgroup) do
    {
      "group"      => "https://gitlab.com/groups/Mouse-Hack/subgroup",
      "permission" => "write",
      "members"    => ["https://gitlab.com/u/kylemacey"],
      "projects"   => ["https://gitlab.com/Mouse-Hack/subgroup/hugo-pages"],
      "name"       => "Mouse-Hack Write Access",
    }
  end

  subject { described_class.new }

  describe "#serialize" do
    subject { described_class.new.serialize(team) }

    it "returns a serialized Team hash" do
      expected = {
        "type" => "team",
        "url" => "https://gitlab.com/groups/Mouse-Hack/teams/mouse-hack-write-access",
        "organization" => "https://gitlab.com/groups/Mouse-Hack",
        "name" => "Mouse-Hack Write Access",
        "description" => nil,
        "permissions" => [
          {
            "repository" => "https://gitlab.com/Mouse-Hack/hugo-pages",
            "access" => "write"
          }
        ],
        "members" => [
          {
            "user" => "https://gitlab.com/u/kylemacey",
            "role" => "member",
          },
        ]
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
      end
    end
  end

  describe "#serialize with subgroup" do
    subject { described_class.new.serialize(team_in_subgroup) }

    it "returns a serialized Team hash" do
      expected = {
        "type" => "team",
        "url" => "https://gitlab.com/groups/Mouse-Hack-subgroup/teams/mouse-hack-write-access",
        "organization" => "https://gitlab.com/groups/Mouse-Hack-subgroup",
        "name" => "Mouse-Hack Write Access",
        "description" => nil,
        "permissions" => [
          {
            "repository" => "https://gitlab.com/Mouse-Hack-subgroup/hugo-pages",
            "access" => "write"
          }
        ],
        "members" => [
          {
            "user" => "https://gitlab.com/u/kylemacey",
            "role" => "member",
          },
        ]
      }

      expected.each do |key, value|
        expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
      end
    end
  end
end
