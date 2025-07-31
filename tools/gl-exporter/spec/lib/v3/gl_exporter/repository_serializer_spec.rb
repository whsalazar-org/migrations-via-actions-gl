require 'spec_helper'

describe GlExporter::RepositorySerializer, :v3 do
  let(:user_project) do
    VCR.use_cassette("v3/gitlab-projects/kylemacey/Spoon-Knife") do
      Gitlab.project('kylemacey', 'Spoon-Knife')
    end
  end

  let(:group_project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  let(:labels) do
    VCR.use_cassette("v3/gitlab-labels/#{project["path_with_namespace"]}") do
      Gitlab.labels(project["id"])
    end
  end

  let(:webhooks) do
    VCR.use_cassette("v3/gitlab-webhooks/#{project["path_with_namespace"]}") do
      Gitlab.webhooks(project["id"])
    end
  end

  let(:project_team_members) do
    VCR.use_cassette("v3/gitlab-collaborators/#{project["path_with_namespace"]}") do
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
          :url            => "https://gitlab.com/kylemacey/Spoon-Knife",
          :owner          => "https://gitlab.com/u/kylemacey",
          :name           => "Spoon-Knife",
          :description    => "This repo is for demonstration purposes only.",
          :website        => nil,
          :private        => false,
          :has_issues     => true,
          :has_wiki       => false,
          :has_downloads  => true,
          :created_at     => "2016-04-27T19:27:08.692Z",
          :git_url        => "tarball://root/repositories/kylemacey/Spoon-Knife.git",
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
    end

    context "when owned by a group" do

      let(:project) { group_project }
      let(:group) do
        VCR.use_cassette("v3/gitlab-export-owner/Mouse-Hack/hugo-pages") do
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
  end
end
