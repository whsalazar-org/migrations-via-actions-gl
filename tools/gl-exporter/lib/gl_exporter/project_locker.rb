require "gitlab"
class GlExporter
  class ProjectLocker
    # Lock and unlock projects

    # Create a new instance of ProjectLocker
    #
    # @param [String] lock_projects whether projects should be locked. One of
    #   "true", "false", "transient"
    def initialize(lock_projects="false")
      @lock_projects = lock_projects
      @locked = false
    end

    # Should projects be locked?
    #
    # @return [Boolean] if projects should be locked
    def lock?
      ["true", "transient"].include?(@lock_projects) && ! @locked
    end

    # Should projects be unlocked?
    #
    # @return [Boolean] if projects should be unlocked
    def unlock?
      @lock_projects == "transient" && @locked
    end

    # Lock a set of projects
    # @param [Array] project_ids an array of project IDs to lock
    # @return [Boolean] true
    def lock_projects(project_ids)
      project_ids.each do |project_id|
        Gitlab.lock(project_id) unless locked?(project_id)
      end
      @locked = true
    end

    # Unlock a set of projects
    # @param [Array] project_ids an array of project IDs to unlock
    # @return [Boolean] false
    def unlock_projects(project_ids)
      project_ids.each do |project_id|
        Gitlab.unlock(project_id) unless locked?(project_id)
      end
      @locked = false
    end

    private

    def locked?(project_id)
      Gitlab.project_by_id(project_id)["archived"]
    end
  end
end
