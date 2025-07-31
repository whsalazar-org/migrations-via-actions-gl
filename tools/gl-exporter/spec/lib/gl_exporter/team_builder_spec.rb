require "spec_helper"

describe GlExporter::TeamBuilder do

  subject { described_class.new }

  describe "#add_member" do
    it "stores data about the member added" do
      subject.add_member("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/u/kylemacey", "write")
      expect(subject.members).to eq([{
        group: "https://gitlab.com/groups/Mouse-Hack",
        member: "https://gitlab.com/u/kylemacey",
        permission: "write",
      }])
    end

    it "will not duplicate information" do
      subject.add_member("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/u/kylemacey", "write")
      subject.add_member("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/u/kylemacey", "write")
      expect(subject.members).to eq([{
        group: "https://gitlab.com/groups/Mouse-Hack",
        member: "https://gitlab.com/u/kylemacey",
        permission: "write",
      }])
    end
  end

  describe "#add_project" do
    it "stores the project" do
      subject.add_project("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/Mouse-Hack/hugo-pages")
      expect(subject.projects).to eq([{
        group: "https://gitlab.com/groups/Mouse-Hack",
        project: "https://gitlab.com/Mouse-Hack/hugo-pages",
      }])
    end

    it "will not duplicate information" do
      subject.add_project("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/Mouse-Hack/hugo-pages")
      subject.add_project("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/Mouse-Hack/hugo-pages")
        expect(subject.projects).to eq([{
        group: "https://gitlab.com/groups/Mouse-Hack",
        project: "https://gitlab.com/Mouse-Hack/hugo-pages",
      }])
    end
  end

  describe "#teams" do
    it "builds team information from its member and project data" do
      subject.add_member("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/u/kylemacey", "write")
      subject.add_project("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/Mouse-Hack/hugo-pages")
      expect(subject.teams).to eq([{
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
            "role" => "member"
          }
        ],
        "created_at" => Time.now.to_s
      }])
    end

    it "builds teams across multiple groups and access levels" do
      subject.add_member("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/u/kylemacey", "write")
      subject.add_member("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/spraints", "write")
      subject.add_member("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/jonmagic", "read")
      subject.add_project("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/Mouse-Hack/hugo-pages")
      subject.add_project("https://gitlab.com/groups/Mouse-Hack", "https://gitlab.com/Mouse-Hack/Spoon-Knife")
      subject.add_member("https://gitlab.com/groups/hackmouse", "https://gitlab.com/u/kylemacey", "admin")
      subject.add_project("https://gitlab.com/groups/hackmouse", "https://gitlab.com/hackmouse/Spoon-Knife")
      expect(subject.teams).to eq([
        {
          "type" => "team",
          "url" => "https://gitlab.com/groups/Mouse-Hack/teams/mouse-hack-write-access",
          "organization" => "https://gitlab.com/groups/Mouse-Hack",
          "name" => "Mouse-Hack Write Access",
          "description" => nil,
          "permissions" => [
            {
              "repository" => "https://gitlab.com/Mouse-Hack/hugo-pages",
              "access" => "write"
            },
            {
              "repository" => "https://gitlab.com/Mouse-Hack/Spoon-Knife",
              "access" => "write"
            }
          ],
          "members" => [
            {
              "user" => "https://gitlab.com/u/kylemacey",
              "role" => "member"
            },
            {
              "user" => "https://gitlab.com/spraints",
              "role" => "member"
            }
          ],
          "created_at" => Time.now.to_s
        },
        {
          "type" => "team",
          "url" => "https://gitlab.com/groups/Mouse-Hack/teams/mouse-hack-read-access",
          "organization" => "https://gitlab.com/groups/Mouse-Hack",
          "name" => "Mouse-Hack Read Access",
          "description" => nil,
          "permissions" => [
            {
              "repository" => "https://gitlab.com/Mouse-Hack/hugo-pages",
              "access" => "read"
            },
            {
              "repository" => "https://gitlab.com/Mouse-Hack/Spoon-Knife",
              "access" => "read"
            }
          ],
          "members" => [
            {
              "user" => "https://gitlab.com/jonmagic",
              "role" => "member"
            }
          ],
          "created_at" => Time.now.to_s
        },
        {
          "type" => "team",
          "url" => "https://gitlab.com/groups/hackmouse/teams/hackmouse-admin-access",
          "organization" => "https://gitlab.com/groups/hackmouse",
          "name" => "hackmouse Admin Access",
          "description" => nil,
          "permissions" => [
            {
              "repository" => "https://gitlab.com/hackmouse/Spoon-Knife",
              "access" => "admin"
            }
          ],
          "members" => [
            {
              "user" => "https://gitlab.com/u/kylemacey",
              "role" => "member"
            }
          ],
          "created_at" => Time.now.to_s
        },
      ])
    end
  end

end
