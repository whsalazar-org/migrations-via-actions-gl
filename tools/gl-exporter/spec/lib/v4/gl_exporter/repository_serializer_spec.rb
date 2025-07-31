require 'spec_helper'

describe GlExporter::RepositorySerializer, :v4 do
  let(:user_project) do
    VCR.use_cassette("v4/gitlab-projects/synthead/test-repo") do
      Gitlab.project('synthead', 'test-repo')
    end
  end

  let(:group_project) do
    VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  let(:subgroup_project) do
    VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/subgroup1/repo1") do
      Gitlab.project("Mouse-Hack/subgroup1", "repo1")
    end
  end

  let(:labels) do
    VCR.use_cassette("v4/gitlab-labels/#{project["path_with_namespace"]}") do
      Gitlab.labels(project["id"])
    end
  end

  let(:webhooks) do
    VCR.use_cassette("v4/gitlab-webhooks/#{project["path_with_namespace"]}") do
      Gitlab.webhooks(project["id"])
    end
  end

  let(:project_team_members) do
    VCR.use_cassette("v4/gitlab-collaborators/#{project["path_with_namespace"]}") do
      Gitlab.project_team_members(project["id"])
    end
  end

  subject { described_class.new }

  before(:each) do
    project["labels"] = labels
    project["webhooks"] = webhooks
    project["collaborators"] = project_team_members
  end

  describe "#serialize" do
    subject { described_class.new.serialize(project) }

    context "when owned by a user" do

      let(:project) { user_project }

      it "returns a serialized Repository hash" do
        expected = {
          :type           => "repository",
          :url            => "https://gitlab.com/synthead/test-repo",
          :owner          => "https://gitlab.com/synthead",
          :name           => "test-repo",
          :description    => "This repo is for demonstration purposes only.",
          :website        => nil,
          :private        => true,
          :has_issues     => true,
          :has_wiki       => true,
          :has_downloads  => true,
          :created_at     => "2017-07-20T00:35:22.243Z",
          :git_url        => "tarball://root/repositories/synthead/test-repo.git",
          :default_branch => "master"
        }

        expected.each do |key, value|
          expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
        end
      end

      it "serializes project webhooks" do
        expect(subject[:webhooks].length).to eq(2)
      end

      it "serializes collaborators" do
        expect(subject[:collaborators]).to_not be_empty
      end

      context "with a GitLab project marked as private" do
        before { project["visibility"] = "private" }

        it "returns a serialized Repository hash with private set to true" do
          expect(subject[:private]).to be true
        end
      end

      context "with a GitLab project marked as public" do
        before { project["visibility"] = "public" }

        it "returns a serialized Repository hash with private set to false" do
          expect(subject[:private]).to be false
        end
      end
    end

    context "when owned by a group" do

      let(:project) { group_project }
      let(:group) do
        VCR.use_cassette("v4/gitlab-export-owner/Mouse-Hack/hugo-pages") do
          Gitlab.group("Mouse-Hack")
        end
      end

      context "when a group is provided" do
        before(:each) do
          project["owner"] = group
        end

        it "returns a serialized Repository hash with an owner" do
          expected = {
            :type           => "repository",
            :url            => "https://gitlab.com/Mouse-Hack/hugo-pages",
            :owner          => "https://gitlab.com/groups/Mouse-Hack",
            :name           => "hugo-pages",
            :description    => "Wanna use something other than jekyll? Try this one weird trick. er, actually a bunch of tricks, glued together.",
            :website        => nil,
            :private        => true,
            :has_issues     => true,
            :has_wiki       => true,
            :has_downloads  => true,
            :created_at     => "2016-05-10T21:15:14.616Z",
            :git_url        => "tarball://root/repositories/Mouse-Hack/hugo-pages.git",
            :wiki_url        => "tarball://root/repositories/Mouse-Hack/hugo-pages.wiki.git",
            :default_branch => "master"
          }

          expected.each do |key, value|
            expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
          end
        end
      end

      context "when a group is not provided" do
        it "returns a serialized Repository hash without an owner" do
          expected = {
            :type           => "repository",
            :url            => "https://gitlab.com/Mouse-Hack/hugo-pages",
            :name           => "hugo-pages",
            :description    => "Wanna use something other than jekyll? Try this one weird trick. er, actually a bunch of tricks, glued together.",
            :website        => nil,
            :private        => true,
            :has_issues     => true,
            :has_wiki       => true,
            :has_downloads  => true,
            :created_at     => "2016-05-10T21:15:14.616Z",
            :git_url        => "tarball://root/repositories/Mouse-Hack/hugo-pages.git",
            :wiki_url        => "tarball://root/repositories/Mouse-Hack/hugo-pages.wiki.git",
            :default_branch => "master"
          }

          expected.each do |key, value|
            expect(subject[key]).to eq(value), "`#{key}` does not match \n\n  expected: #{value.inspect}\n       got: #{subject[key].inspect}\n"
          end
        end
      end
    end

    context "with a repository in a subgroup" do
      let(:project) { subgroup_project }

      it "returns a serialized Repository hash" do
        expect(subject).to include(
          type: "repository",
          url: "https://gitlab.com/Mouse-Hack-subgroup1/repo1",
          owner: nil,
          name: "Repo1",
          description: "",
          website: nil,
          private: true,
          has_issues: true,
          has_wiki: true,
          has_downloads: true,
          labels: [],
          webhooks: [],
          collaborators: [],
          created_at: "2022-04-05T14:45:17.969Z",
          # :git_url joins the group and its subgroups with "-".
          git_url: "tarball://root/repositories/Mouse-Hack-subgroup1/repo1.git",
          default_branch: "main",
          # :wiki_url joins the group and its subgroups with "-".
          wiki_url: "tarball://root/repositories/Mouse-Hack-subgroup1/repo1.wiki.git"
        )
      end
    end
  end
end
