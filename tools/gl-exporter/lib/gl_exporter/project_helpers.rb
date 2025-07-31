class GlExporter
  module ProjectHelpers
    def org_from_path_with_namespace(path_with_namespace)
      groups = path_with_namespace.split("/")
      repo = groups.pop
      joined_groups = groups.join("-")

      [joined_groups, repo].join("/")
    end
  end
end
