require "active_support/cache"
require "active_support/cache/file_store"
require "faraday"
require "faraday_middleware"
require "faraday-http-cache"
require "faraday/cache_headers"
require "fileutils"
require "gitlab"
require "gitlab/url_builder"
require "open-uri"
require "tmpdir"
require "csv"
require "posix-spawn"
require "rugged"
require "active_support/core_ext/object/blank"
require "gl_exporter/project_helpers"
require "gl_exporter/logging"
require "gl_exporter/safe_transaction"
require "gl_exporter/archive_builder"
require "gl_exporter/team_builder"
require "gl_exporter/base_serializer"
require "gl_exporter/attachment_serializer"
require "gl_exporter/organization_serializer"
require "gl_exporter/user_serializer"
require "gl_exporter/commit_comment_serializer"
require "gl_exporter/label_serializer"
require "gl_exporter/webhook_serializer"
require "gl_exporter/collaborator_serializer"
require "gl_exporter/issue_serializer"
require "gl_exporter/release_serializer"
require "gl_exporter/issue_comment_serializer"
require "gl_exporter/pull_request_serializer"
require "gl_exporter/member_serializer"
require "gl_exporter/milestone_serializer"
require "gl_exporter/repository_serializer"
require "gl_exporter/protected_branch_serializer"
require "gl_exporter/team_serializer"
require "gl_exporter/user_content_rewritable"
require "gl_exporter/attachable"
require "gl_exporter/authorable"
require "gl_exporter/writable"
require "gl_exporter/storable"
require "gl_exporter/model_url_service"
require "gl_exporter/serialized_model_writer"
require "gl_exporter/project_exporter"
require "gl_exporter/project_locker"
require "gl_exporter/url_templates"
require "gl_exporter/storage"
require "gl_exporter/migratable_resource"
require "gl_exporter/issue_exporter"
require "gl_exporter/issue_note_exporter"
require "gl_exporter/merge_request_exporter"
require "gl_exporter/merge_request_note_exporter"
require "gl_exporter/commit_comment_exporter"
require "gl_exporter/protected_branch_exporter"
require "forwardable"
require "logger"
require "pry"

class GlExporter
  include Logging
  include SafeExecution

  log_handled_exceptions_to :logger

  attr_accessor :options

  OPTIONAL_MODELS = %w{issues merge_requests commit_comments hooks wiki}
  MINIMUM_VERSION = "8.13.0"

  def initialize(options={})
    @options = options
    output_logger.info "Creating working directory in #{staging_dir}"
  end

  # Begins the export process for a single project or a manifest of projects
  #
  # @param [Hash] options the options for the export
  # @option options [String] :namespace the namespace of the project to export
  # @option options [String] :project the slug of the project to export
  # @option options [String] :manifest a path pointing to a CSV file with a list
  #   of namespaces and project names
  # @option options [String] :output_path where the migration archive should be
  #   saved
  # @option options [String] :lock_projects if and how projects should be locked
  def export
    set_ssl_options!
    check_version!
    @project_locker = ProjectLocker.new(options[:lock_projects])
    if options[:namespace] && options[:project]
      export_project(Gitlab.project(options[:namespace], options[:project]))
    end
    if options[:manifest]
      export_from_list(options[:manifest])
    end

    team_builder.write!

    raise "Nothing was exported!" unless archiver.used?
    archiver.create_tar(options[:output_path])
  end

  def set_ssl_options!
    Gitlab.ssl_verify = options[:ssl_verify]
  end

  def models_to_export
    options[:models].to_a
  end

  def without_renumbering
    options[:without_renumbering]&.to_sym
  end

  def archiver
    @archiver ||= ArchiveBuilder.new(current_export: self)
  end

  def team_builder
    @team_builder ||= TeamBuilder.new(current_export: self)
  end

  # Determines the path on disk for gl-exporter
  #
  # @param [String] rel_path relative path to be appended to the project path
  # @return [String] If rel_path is provided, it will return the project path
  #   with rel_path appended. Otherwise, returns the project path
  def self.path(rel_path=nil)
    project_path = File.expand_path("../../", __FILE__)
    if rel_path
      File.join(project_path, rel_path)
    else
      project_path
    end
  end

  # Determines if the library is being run in a test environment
  #
  # @return [Boolean]
  def self.test?
    ENV["GL_EXPORTER_ENV"] == "test"
  end

  # A tmpdir where the archive's contents are staged
  def staging_dir
    @staging_dir ||= Dir.mktmpdir "gl-exporter"
  end

  def logs_dir
    @logs_dir ||= FileUtils.mkdir_p(File.join(staging_dir, "log/")).first
  end

  # Checks if the Gitlab instance has a version greater than MINIMUM_VERSION. It
  # will raise an error if it does not
  def check_version!
    # Strip out atypical semantic versioning suffixes such as "ce" or "ee"
    gitlab_version = Gitlab.version["version"][/[\d\.]+\d(-pre|-rc\d)?/]
    if Gem::Version.new(gitlab_version) >= Gem::Version.new(MINIMUM_VERSION)
      true
    else
      raise BadVersion.new(gitlab_version)
    end
  end

  def export_project(project)
    project_exporter = ProjectExporter.new(project, current_export: self)
    @project_locker.lock_projects([project["id"]]) if @project_locker.lock?
    project_exporter.export
    @project_locker.unlock_projects([project["id"]]) if @project_locker.unlock?
  end

  def export_from_list(file_path)
    projects = projects_from_file(file_path)
    project_ids = projects.map { |project| project["id"] }

    @project_locker.lock_projects(project_ids) if @project_locker.lock?

    projects.each do |project|
      export_project(project)
    end

    @project_locker.unlock_projects(project_ids) if @project_locker.unlock?
  end

  def projects_from_file(file_path)
    CSV.read(file_path).map do |namespace, project_name|
      if project_name.nil?
        output_logger.error "No project name found on row #{namespace}"
        next
      end

      project = nil
      safely {
        project = Gitlab.project(namespace, project_name)
      }.error {
        output_logger.error "Unable to export project #{namespace}/#{project_name}"
      }
      project
    end.compact
  end

  class BadVersion < StandardError;
    def initialize(version)
      @version = version
    end

    def message
      <<-EOF
This utility requires GitLab version #{MINIMUM_VERSION} or greater.
The version returned by GitLab was #{@version}.
      EOF
    end
  end

  at_exit do
    puts "Cleaning up HTTP cache..."
    Gitlab.http_cache.clear
  end
end
