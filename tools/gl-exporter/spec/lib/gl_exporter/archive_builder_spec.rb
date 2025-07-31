require "spec_helper"
require "gl_exporter/tar_utils"
require "digest/md5"

describe GlExporter::ArchiveBuilder, :v4 do
  include GlExporter::TarUtils

  subject(:archive_builder) { described_class.new }
  let(:tarball_path) { Tempfile.new("string").path }
  let(:files) { `tar tfz #{tarball_path}`.split }

  def file_md5sum(path)
    Digest::MD5.file(path).hexdigest
  end

  it "makes a tarball with a json file" do
    archive_builder.write(model_name: "mouse", data: { "foo" => "bar" })
    archive_builder.create_tar(tarball_path)

    expect(files).to include("./mice_000001.json")
  end

  it "adds a schema.json" do
    archive_builder.create_tar(tarball_path)

    expect(files).to include("./schema.json")

    dir = Dir.mktmpdir "archive_builder"

    extract_archive(tarball_path, dir) do
      path = File.join(dir, "schema.json")
      json_data = File.read(path)
      expect(JSON.load(json_data)).to eq({ "version" => "1.2.0" })
    end
  end

  it "adds a urls.json" do
    archive_builder.create_tar(tarball_path)

    expect(files).to include("./urls.json")
  end

  context "with a repository in a subgroup" do
    let(:project) do
      VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/subgroup1/repo1") do
        Gitlab.project("Mouse-Hack/subgroup1", "repo1")
      end
    end

    it "calls #archive_repo to clone to a directory with the group and subgroups joined by hyphens" do
      expect(archive_builder).to receive(:archive_repo).with(
        clone_url: "https://gitlab.com/Mouse-Hack/subgroup1/repo1.git",
        to: "#{archive_builder.staging_dir}/repositories/Mouse-Hack-subgroup1/repo1.git",
        credentials: be_a(Rugged::Credentials::UserPassword)
      )

      archive_builder.clone_repo(project)
    end
  end

  describe "#clone_wiki" do
    let(:project) do
      VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/hugo-pages") do
        Gitlab.project("Mouse-Hack", "hugo-pages")
      end
    end

    let(:wiki_fixture_path) { "spec/fixtures/repositories/Mouse-Hack/hugo-pages.wiki.git" }
    let(:rugged_wiki) { Rugged::Repository.new(wiki_fixture_path) }

    it "clones the wiki information" do
      expect(archive_builder).to receive(:archive_repo).with(
        clone_url: "https://gitlab.com/Mouse-Hack/hugo-pages.wiki.git",
        to: "#{archive_builder.staging_dir}/repositories/Mouse-Hack/hugo-pages.wiki.git",
        credentials: be_a(Rugged::Credentials::UserPassword)
      ).and_return(rugged_wiki)

      archive_builder.clone_wiki(project)
    end

    context "with a repository in a subgroup" do
      let(:project) do
        VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/subgroup1/repo1") do
          Gitlab.project("Mouse-Hack/subgroup1", "repo1")
        end
      end

      it "calls #archive_repo to clone to a directory with the group and subgroups joined by hyphens" do
        expect(archive_builder).to receive(:archive_repo).with(
          clone_url: "https://gitlab.com/Mouse-Hack/subgroup1/repo1.wiki.git",
          to: "#{archive_builder.staging_dir}/repositories/Mouse-Hack-subgroup1/repo1.wiki.git",
          credentials: be_a(Rugged::Credentials::UserPassword)
        ).and_return(rugged_wiki)

        archive_builder.clone_wiki(project)
      end
    end

    context "when wiki head ref is master" do
      before(:each) { allow(archive_builder).to receive(:archive_repo).and_return(rugged_wiki) }

      it "does not attempt to change the head ref to master" do
        expect(rugged_wiki.branches).to_not receive(:rename)

        archive_builder.clone_wiki(project)
      end
    end

    context "when wiki head ref not master" do
      let(:wiki_fixture_path) { "spec/fixtures/repositories/Mouse-Hack/wiki-with-main-branch.wiki.git" }

      before(:each) { allow(archive_builder).to receive(:archive_repo).and_return(rugged_wiki) }

      it "changes the head ref to master" do
        expect(rugged_wiki.branches).to receive(:rename).with("main", "master")

        archive_builder.clone_wiki(project)
      end
    end
  end

  describe "#save_attachment" do
    context "with an existing attachment" do
      subject(:save_attachment) do
        VCR.use_cassette("v4/remote-attachment") do
          archive_builder.save_attachment("test.png", "http://httpstat.us/200")
        end
      end

      it { is_expected.to  eq(true) }

      context "with SSL verification disabled", :vcr do
        around do |example|
          with_ssl_verify(false) { example.run }
        end

        it "ignores SSL errors" do
          archive_builder.save_attachment("tmp/test.png", "https://self-signed.badssl.com/")
        end
      end

      context "with SSL verification enabled", :vcr do
        around do |example|
          with_ssl_verify(true) { example.run }
        end

        it "raises SSL errors" do
          expect{
            archive_builder.save_attachment("tmp/test.png", "https://self-signed.badssl.com/")
          }.to raise_error(Faraday::SSLError)
        end
      end
    end

    context "with a unicode attachment" do
      subject(:save_attachment) do
        VCR.use_cassette("v4/remote-attachment-unicode") do
          archive_builder.save_attachment("test.png", "https://placehold.it/400?text=")
        end
      end

      it { is_expected.to  eq(true) }
    end

    context "with valid attachment download", :vcr do
      let(:staging_dir) { Dir.mktmpdir "archive_builder" }
      let(:expected_md5sum) { "b3341d1acf8ac1cf833debf0d265dbe4" }
      let(:file_name) { "1x1.png" }
      let(:attachment_path) { File.join(staging_dir, "attachments", file_name) }

      subject(:save_attachment) do
        archive_builder.save_attachment(file_name, "https://placehold.it/1")
      end

      it { is_expected.to  eq(true) }

      it "saves attachment content to disk" do
        allow_any_instance_of(
          GlExporter::ArchiveBuilder
        ).to receive(:staging_dir).and_return(staging_dir)

        subject

        expect(file_md5sum(attachment_path)).to eq(expected_md5sum)
      end
    end

    context "with a missing attachment" do
      subject(:save_attachment) do
        VCR.use_cassette("v4/remote-attachment-404") do
          archive_builder.save_attachment("test.png", "http://httpstat.us/404")
        end
      end

      it { is_expected.to  eq(false) }
    end

    context "with an erroneous attachment" do
      subject(:save_attachment) do
        VCR.use_cassette("v4/remote-attachment-422") do
          archive_builder.save_attachment("test.png", "http://httpstat.us/422")
        end
      end

      it { is_expected.to  eq(false) }
    end

    # See https://github.com/github/gl-exporter/issues/41
    context "with an inaccessible attachment" do
      subject(:save_attachment) do
        VCR.use_cassette("v4/remote-attachment-302") do
          archive_builder.save_attachment("Sample.pdf", "http://httpstat.us/302", "https://gitlab.com/Mouse-Hack/hugo-pages/issues/5#note_11735615")
        end
      end

      it { is_expected.to  eq(false) }

      it "logs a message to the output" do
        expect(archive_builder.current_export.output_logger).to receive(:warn)
        subject
      end

      it "logs a message to the log" do
        expect(archive_builder.current_export.logger).to receive(:error)
        subject
      end
    end

    context "with a Faraday::ClientError" do
      subject(:save_attachment) do
        archive_builder.save_attachment("Sample.pdf", "http://httpstat.us/302", "https://gitlab.com/Mouse-Hack/hugo-pages/issues/5#note_11735615")
      end
      let(:logger_double) { instance_double(Logger) }

      before do
        allow(Gitlab).to receive_message_chain(:connection, :get) { raise Faraday::ClientError.new("message") }
      end

      it "logs an error to the output via current_export" do
        allow(archive_builder.current_export).to receive(:output_logger) { logger_double }
        expect(logger_double).to receive(:error)
        subject
      end

      it "logs an error to the log via current_export" do
        allow(archive_builder.current_export).to receive(:logger) { logger_double }
        expect(logger_double).to receive(:error)
        subject
      end
    end
  end
end
