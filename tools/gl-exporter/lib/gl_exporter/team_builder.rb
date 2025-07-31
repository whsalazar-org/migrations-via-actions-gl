class GlExporter
  class TeamBuilder
    attr_reader :current_export, :archiver

    def initialize(current_export: GlExporter.new)
      @current_export = current_export
      @archiver = current_export.archiver
    end

    # Add a member to be serialized and written later
    #
    # @param [String] group the GitLab URL of the group which owns the membership
    # @param [String] member the GitLab URL of the user which owns the membership
    # @param [String] permission the access level to be granted to the member;
    #   can be "pull", "push", or "admin"
    def add_member(group, member, permission)
      return if member_record_exists?(group, member, permission)
      storage.store("team_members", {
        group: group,
        member: member,
        permission: permission,
      })
    end

    # Add a project to be added to all the groups' teams later
    #
    # @param [String] group the GitLab URL of the group which owns the project
    # @param [String] project the GitLab URL of the project
    def add_project(group, project)
      return if project_record_exists?(group, project)
      storage.store("group_projects", {
        group: group,
        project: project,
      })
    end

    # Returns all members that have been stored
    #
    # @return [Array]
    def members
      storage.all("team_members")
    end

    # Returns all projects that have been stored
    #
    # @return [Array]
    def projects
      storage.all("group_projects")
    end


    # Serialize and return a flat array of all the team permutations
    #
    # @return [Array]
    def teams
      members.group_by { |member| member[:group] }.flat_map do |group, records|
        records.group_by { |record| record[:permission] }.flat_map do |permission, records|
          build_team(group, permission, records.map { |r| r[:member] }, projects_for_group(group))
        end
      end
    end

    def write!
      teams.each(&method(:write_team))
    end

    private

    def storage
      GlExporter::Storage.instance
    end

    def member_record_exists?(group, member, permission)
      storage.all("team_members").any? do |record|
        record[:group] == group &&
        record[:member] == member &&
        record[:permission] == permission
      end
    end

    def project_record_exists?(group, project)
      storage.all("group_projects").any? do |record|
        record[:group] == group &&
        record[:project] == project
      end
    end

    def projects_for_group(group)
      projects.select { |project| project[:group] == group }
    end

    def build_team(group, permission, members, projects)
      team = faux_team_model(group, permission, members, projects)
      TeamSerializer.new(:model_url_service => model_url_service).serialize(team)
    end

    def faux_team_model(group, permission, members, projects)
      {
        "group"      => group,
        "permission" => permission,
        "members"    => members,
        "projects"   => projects.map { |p| p[:project] },
        "name"       => build_team_name(group, permission),
      }
    end

    # Largely copied from ProjectExporter#serialize, but can be refactored later
    def write_team(team)
      model_url = team["url"]
      if archiver.seen?("team", model_url)
        current_export.logger.info "team: #{model_url} already serialized"
        return false
      else
        current_export.logger.info "team: #{model_url} serialized to json"
        archiver.write(model_name: "team", data: team)
        archiver.seen("team", model_url)
        return true
      end
    end

    def build_team_name(group, permission)
      group_name = group[%r{http.+/groups/(.+)}, 1]

      "#{group_name} #{permission.capitalize} Access"
    end

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end
  end
end
