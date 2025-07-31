package cmd

import (
	"fmt"
	"os"

	gl "github.com/ps-resources/gh-glx-migrator/internal/gitlab"
	ghlog "github.com/ps-resources/gh-glx-migrator/pkg/logger"

	"github.com/spf13/cobra"
	"go.uber.org/zap"
)

func ExportArchiveCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "export-archive",
		Short: "Generate an archive from GitLab using gl-exporter",
		Long: `Generate an archive from a GitLab project for migration.
GitLab credentials and export options must be provided either via flags or environment variables.
Either provide a CSV file listing the groups/repositories to export,
or provide the GitLab namespace and project.
`,
		Example: `gh glx export-archive \
                --gl-namespace gitlab-org \
                --gl-project gitlab-ce \
                --output-file migration_archive.tar.gz

              # Using CSV file instead:
              gh glx export-archive \
              --csv-file export.csv \
              --output-file migration_archive.tar.gz`,
		RunE: exportArchive,
	}

	// Optional CSV file flag if a list of groups/repositories is provided.
	cmd.Flags().String("csv-file", "", "CSV file listing GitLab groups and repositories (optional)")
	cmd.Flags().String("output-file", "migration_archive.tar.gz", "Output archive file name")
	cmd.Flags().String("gl-api-endpoint", "", "GitLab API endpoint (e.g., https://gitlab.example.com/api/v4)")
	cmd.Flags().String("gl-username", "", "GitLab username")
	cmd.Flags().String("gl-api-token", "", "GitLab API token")
	cmd.Flags().String("gl-namespace", "", "GitLab namespace (used if CSV file is not provided)")
	cmd.Flags().String("gl-project", "", "GitLab project (used if CSV file is not provided)")

	if err := cmd.MarkFlagRequired("output-file"); err != nil {
		ghlog.Logger.Error("failed to mark output-file as required", zap.Error(err))
		return nil
	}

	return cmd
}

func exportArchive(cmd *cobra.Command, args []string) error {
	ghlog.Logger.Info("Reading input values for generating archive from GitLab")

	csvFile, _ := cmd.Flags().GetString("csv-file")
	outputFile, _ := cmd.Flags().GetString("output-file")
	glNamespace, _ := cmd.Flags().GetString("gl-namespace")
	glProject, _ := cmd.Flags().GetString("gl-project")

	// If no CSV file is provided then namespace and project must be set.
	if csvFile == "" {
		if glNamespace == "" || glProject == "" {
			return fmt.Errorf("either provide a CSV file or set both gl-namespace and gl-project")
		}
	} else {
		// If a CSV file is provided and namespace/project are also set, warn that CSV takes precedence.
		if glNamespace != "" || glProject != "" {
			ghlog.Logger.Warn("CSV file provided; gl-namespace and gl-project will be ignored")
		}
	}

	gitLabAPIEndpoint := os.Getenv("GITLAB_API_ENDPOINT")
	if gitLabAPIEndpoint == "" {
		gitLabAPIEndpoint = "gitlab.com/api/v4"
	}

	opts := &gl.GLExporterOptions{
		CsvFile:           csvFile,
		OutputFile:        outputFile,
		GitLabAPIEndpoint: gitLabAPIEndpoint,
		GitLabUsername:    os.Getenv("GITLAB_USERNAME"),
		GitLabAPIToken:    os.Getenv("GITLAB_PAT"),
		DockerImage:       os.Getenv("GL_EXPORTER_DOCKER_IMAGE"),
		GitLabNamespace:   glNamespace,
		GitLabProject:     glProject,
	}

	if err := gl.ExportFromGitLab(opts); err != nil {
		return err
	}
	return nil
}
