# Why yes, yes this is shamefully stolen from gh-migrator

class GlExporter
  module GitHelpers
    # Create a copy of a repository for archiving.
    # @param [Hash] project the project containing the repository to be archived
    # @param [String] to the path where the copy of the repository will be
    #   stored before it is added to the archive tarball.
    # @params [Rugged::Credentials] credentials the git credentials to authenticate
    #  the clone with
    #
    def archive_repo(clone_url:, to:, credentials: nil)
      # Kill the last attempt to export.
      FileUtils.rm_rf(to)
      clone_mirror(clone_url, to, credentials)
    end

    def change_wiki_head_ref(wiki)
      return unless contains_branch?(wiki, "main") && !contains_branch?(wiki, "master")

      wiki.branches.rename("main", "master")
    end

    def clone_certificate_check
      if gitlab_ssl_no_verify
        Proc.new { true }
      end
    end

    private

    def contains_branch?(repo, branch)
      repo.branches.any? { |b| b.name == branch }
    end

    def clone_mirror(clone_url, to, credentials)
      Rugged::Repository.init_at(to, true).tap do |repository|
        repository.remotes.create("origin", clone_url).tap do |remote|
          remote.fetch("+refs/*:refs/*", credentials: credentials, certificate_check: clone_certificate_check)
        end
      end
    end

    def gitlab_ssl_no_verify
      !Gitlab.ssl_verify
    end
  end
end
