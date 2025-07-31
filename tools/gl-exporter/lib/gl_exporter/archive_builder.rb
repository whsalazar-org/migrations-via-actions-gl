require "gl_exporter/git_helpers"
require "gl_exporter/tar_utils"
require "addressable"

class GlExporter
  # Persists all the data for an export.
  class ArchiveBuilder
    include GitHelpers
    include ProjectHelpers
    include TarUtils
    include Logging

    attr_reader :current_export

    class AttachmentNotSaved < StandardError;end;

    def initialize(current_export: GlExporter.new)
      @current_export = current_export
    end

    # Write a record with the given type
    def write(model_name:, data:)
      file_for(model_name).add(data)
    end

    # Clone a project's Git repository to the staging dir
    def clone_repo(project)
      archive_repo(
        clone_url: repo_clone_url(project),
        to: repo_path(project),
        credentials: git_credentials
      )
    end

    # Clone a project's wiki to the staging dir
    def clone_wiki(project)
      wiki = archive_repo(
        clone_url: wiki_clone_url(project),
        to: wiki_path(project),
        credentials: git_credentials
      )

      change_wiki_head_ref(wiki)
    end

    # Put all of the data into a tar file and dispose of temporary files.
    def create_tar(path)
      files.values.each { |file| file.close }
      write_json_file("urls.json", UrlTemplates.new.templates)
      write_json_file("schema.json", {:version => "1.2.0"})
      create_archive(staging_dir, File.expand_path(path))
      FileUtils.remove_entry_secure staging_dir
    end

    # Returns true if anything was written to the archive.
    def used?
      files.any?
    end

    # Write a hash to a JSON file
    #
    # @param [String] path the path to the file to be written
    # @param [Hash] contents the Hash to be converted to JSON and written to
    #   file
    def write_json_file(path, contents)
      File.open(File.join(staging_dir, path), "w") do |file|
        file.write(JSON.pretty_generate(contents))
      end
    end

    # Determines whether or not a model has been exported. Used for caching.
    #
    # @param [String] model_name the type of model to check
    # @param [String] url the url of the model to check
    # @return [Boolean]
    def seen?(model_name, url)
      !!(seen_record[model_name] && seen_record[model_name][url])
    end

    # Indicates that a model has been exported. Used for caching.
    #
    # @param [String] model_name the type of model to cache
    # @param [String] url the url of the model to cache
    def seen(model_name, url)
      seen_record[model_name] ||= {}
      seen_record[model_name][url] = true
    end

    # The path where repositories are written to disk
    #
    # @param [Hash] project the project that will be written to disk
    # @return [String] the path where this project's repository will be written
    #   to disk
    def repo_path(project)
      org_name = org_from_path_with_namespace(project["path_with_namespace"])

      "#{staging_dir}/repositories/#{org_name}.git"
    end

    def wiki_path(project)
      repo_path(project).gsub(/\.git\z/, ".wiki.git")
    end

    def save_attachment(attach_path, remote_asset_url, parent_url = nil)
      save_path = File.join(staging_dir, "attachments", attach_path)
      FileUtils.mkdir_p(File.dirname(save_path))

      attachment_data = Gitlab.connection.get(remote_asset_url)

      File.write(
        save_path,
        attachment_data.body,
        mode: "wb"
      )

      if parent_url.present?
        raise AttachmentNotSaved if save_attachment_status(remote_asset_url) == 302
      end

      true
    rescue URI::InvalidURIError => e
      if e.message[/^URI must be ascii only/]
        remote_asset_url = Addressable::URI.parse(remote_asset_url).normalize.to_s

        retry
      else
        raise
      end
    rescue Faraday::ClientError => error
      if error.is_a?(Faraday::SSLError)
        raise
      end

      [current_export.logger, current_export.output_logger].each do |logger|
        logger.error "Could not download '#{remote_asset_url}': #{error.message}"
      end
      false
    rescue AttachmentNotSaved => error
      current_export.output_logger.warn(
        "Skipped exporting attachment from #{parent_url}. See gl-exporter.log for more details"
      )

      current_export.logger.error(
        "Could not save attachment #{remote_asset_url} from #{parent_url}: #{error.message}"
      )
      false
    end

    def staging_dir
      current_export.staging_dir
    end

    private

    def save_attachment_status(url)
      Gitlab.connection.head(url, private_token: token).status
    rescue URI::InvalidURIError => e
      if e.message[/^URI must be ascii only/]
        url = URI.encode(url)
        retry
      else
        raise
      end
    end

    def token
      Gitlab.token
    end

    def repo_clone_url(project)
      # Fall back to ssh if no username is provided
      if Gitlab.username.present?
        project["http_url_to_repo"]
      else
        project["ssh_url_to_repo"]
      end
    end

    def wiki_clone_url(project)
      repo_clone_url(project).gsub(/\.git\z/, ".wiki.git")
    end

    def git_credentials
      if Gitlab.username.present?
        Rugged::Credentials::UserPassword.new(
          username: Gitlab.username,
          password: Gitlab.token
        )
      else
        Rugged::Credentials::SshKeyFromAgent.new
      end
    end

    def seen_record
      @seen_record ||= {}
    end

    def file_for(model_name)
      files[model_name]
    end

    def files
      @files ||= Hash.new { |h,k| h[k] = SerializedModelWriter.new(staging_dir, k) }
    end
  end
end
