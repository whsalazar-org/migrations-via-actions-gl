require "spec_helper"

class GlExporter
  describe GitHelpers do
    class Helper; include GitHelpers; end

    subject(:helper) { Helper.new }

    after do
      if File.directory?("tmp/Spoon-Knife")
        FileUtils.remove_dir("tmp/Spoon-Knife")
      end
      if File.directory?("tmp/hugo-pages.git")
        FileUtils.remove_dir("tmp/hugo-pages.git")
      end
    end

    describe "#archive_repo", :vcr do
      it "clones a repository", :vcr do
        helper.archive_repo(
          clone_url: "./spec/fixtures/Spoon-Knife",
          to: "tmp/Spoon-Knife"
        )

        cloned_repo = Rugged::Repository.discover("tmp/Spoon-Knife")

        origin = cloned_repo.remotes["origin"]

        expect(origin.url).to match("spec/fixtures/Spoon-Knife")
      end

      it "sets up tracking branches" do
        helper.archive_repo(
          clone_url: "./spec/fixtures/Spoon-Knife",
          to: "tmp/Spoon-Knife"
        )

        cloned_repo = Rugged::Repository.discover("tmp/Spoon-Knife")

        local_branches = cloned_repo.branches.reject(&:remote?)

        branch_names = local_branches.map(&:name)

        expect(branch_names).to eq(%w(change-the-title master test-branch))
      end

      it "sets up all refs" do
         helper.archive_repo(
          clone_url: "./spec/fixtures/repositories/Mouse-Hack/hugo-pages.git",
          to: "tmp/hugo-pages.git"
        )

        cloned_repo = Rugged::Repository.discover("tmp/hugo-pages.git")

        ref_names = cloned_repo.refs.map(&:name)

        expect(ref_names).to include("refs/merge-requests/1/head")
      end

      it "doesn't cache credentials" do
        credentials = Rugged::Credentials::UserPassword.new(
          username: "exampleuser",
          password: "examplepassword"
        )

        helper.archive_repo(
          clone_url: "./spec/fixtures/Spoon-Knife",
          to: "tmp/Spoon-Knife",
          credentials: credentials
        )

        cloned_repo = Rugged::Repository.discover("tmp/Spoon-Knife")

        config = cloned_repo.config.to_hash

        expect(config.to_s).to_not match("exampleuser")
        expect(config.to_s).to_not match("examplepassword")
      end

      it "clones bare" do
        helper.archive_repo(
          clone_url: "./spec/fixtures/Spoon-Knife",
          to: "tmp/Spoon-Knife"
        )

        expect(Dir.exist?("tmp/Spoon-Knife/.git")).to be false
        expect(File.exist?("tmp/Spoon-Knife/HEAD")).to be true
      end
    end

    describe "#clone_certificate_check" do
      subject(:clone_certificate_check) { helper.clone_certificate_check }

      context "with SSL verification enabled" do
        around do |example|
          with_ssl_verify(true) { example.run }
        end

        it { is_expected.to be_nil }
      end

      context "with SSL verification disabled" do
        around do |example|
          with_ssl_verify(false) { example.run }
        end

        it "resolves to true" do
          result = clone_certificate_check.call
          expect(result).to eq(true)
        end
      end
    end
  end
end
