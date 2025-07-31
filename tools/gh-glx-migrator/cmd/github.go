package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/ps-resources/gh-glx-migrator/internal/github"
	ghlog "github.com/ps-resources/gh-glx-migrator/pkg/logger"

	"github.com/spf13/cobra"
	"go.uber.org/zap"
)

func GetOrgInfoCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "get-org-info",
		Short: "Get organization information from GitHub",
		Long: `Get organization information from GitHub.

GitHub credentials must be configured via environment variables.`,
		Example: `gh glx get-org-info --org my-org`,
		RunE:    getOrgInfoHelper,
	}
	cmd.Flags().String("org", "", "Organization name")
	err := cmd.MarkFlagRequired("org")

	if err != nil {
		ghlog.Logger.Error("failed to mark flag as required", zap.Error(err))
		return nil
	}
	return cmd
}

func CreateMigrationSourceCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "create-migration-source",
		Short: "Create migration source",
		Long: `Create migration source.

GitHub credentials must be configured via environment variables.`,
		Example: `gh glx create-migration-source --owner my-org --name my-migration-source`,
		RunE:    createMigrationSource,
	}
	cmd.Flags().String("owner", "", "Owner ID")
	cmd.Flags().String("name", "", "Migration source name")
	return cmd
}

func StartMigrationCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "migrate",
		Short: "Start a repository migration",
		Long: `Start a repository migration from GitLab to GitHub.
			
GitHub credentials must be configured via environment variables.`,
		Example: `gh glx migrate --migration-source-id MS_xxx --org-owner-id O_xxx --source-repo https://gitlab.com/org/repo --archive-url https://s3.amazonaws.com/archive.tar --visibility private --repo-name my-repo`,
		RunE:    startMigration,
	}

	// Add flags with default values
	cmd.Flags().String("migration-source-id", "", "Migration source ID")
	cmd.Flags().String("org-owner-id", "", "Organization owner ID")
	cmd.Flags().String("source-repo", "", "Source repository URL")
	cmd.Flags().String("archive-url", "", "Archive URL")
	cmd.Flags().String("visibility", "private", "Repository visibility (private/internal/public)")
	cmd.Flags().String("repo-name", "", "Destination repository name (defaults to source repo name if not specified)")

	// Mark required flags
	errSource := cmd.MarkFlagRequired("migration-source-id")
	if errSource != nil {
		ghlog.Logger.Error("failed to mark flag as required", zap.Error(errSource))
		return nil
	}

	errOwner := cmd.MarkFlagRequired("org-owner-id")
	if errOwner != nil {
		ghlog.Logger.Error("failed to mark flag as required", zap.Error(errOwner))
		return nil
	}

	errRepo := cmd.MarkFlagRequired("source-repo")
	if errRepo != nil {
		ghlog.Logger.Error("failed to mark flag as required", zap.Error(errRepo))
		return nil
	}

	errUrl := cmd.MarkFlagRequired("archive-url")
	if errUrl != nil {
		ghlog.Logger.Error("failed to mark flag as required", zap.Error(errUrl))
		return nil
	}

	return cmd
}

func getOrgInfoHelper(cmd *cobra.Command, args []string) error {
	ghlog.Logger.Info("Reading input values for getting organization information from GitHub")

	org, _ := cmd.Flags().GetString("org")

	// Add the field and json flags
	cmd.Flags().String("field", "", "Specific field to extract (id, databaseId, name, login)")
	cmd.Flags().Bool("json", false, "Output result as JSON")

	field, _ := cmd.Flags().GetString("field")
	jsonOutput, _ := cmd.Flags().GetBool("json")

	var orgMap map[string]interface{}
	orgMap, err := fetchOrgInfo(org)
	if err != nil {
		return fmt.Errorf("failed to fetch organization information: %v", err)
	}

	// Handle JSON output format
	if jsonOutput {
		jsonData, err := json.MarshalIndent(orgMap, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal data to JSON: %v", err)
		}
		fmt.Println(string(jsonData))
		return nil
	}

	// Extract and print specific field if requested
	if field != "" {
		switch strings.ToLower(field) {
		case "id":
			fmt.Println(orgMap["id"])
		case "databaseid":
			fmt.Println(orgMap["databaseId"])
		case "name":
			fmt.Println(orgMap["name"])
		case "login":
			fmt.Println(orgMap["login"])
		default:
			return fmt.Errorf("unknown field: %s. Available fields: id, databaseId, name, login", field)
		}
		return nil
	}

	// Default output - log each field separately
	ghlog.Logger.Info("organization: " + fmt.Sprintf("%v", orgMap["name"]))
	ghlog.Logger.Info("login: " + fmt.Sprintf("%v", orgMap["login"]))
	ghlog.Logger.Info("id: " + fmt.Sprintf("%v", orgMap["id"]))
	ghlog.Logger.Info("databaseId: " + fmt.Sprintf("%v", orgMap["databaseId"]))

	return nil
}

// create a fetchOrgInfo function that takes org as input and return orgMap
func fetchOrgInfo(org string) (map[string]interface{}, error) {
	orgInfo, err := github.GetOrgInfo(org)
	if err != nil {
		ghlog.Logger.Debug("failed to get organization information from GitHub", zap.Error(err))
		return nil, fmt.Errorf("failed to get organization information from GitHub: %v", err)
	}

	ghlog.Logger.Info("Organization information from GitHub", zap.Any("orgInfo", orgInfo))

	// Handle the *interface{} case specifically
	var orgMap map[string]interface{}

	// First try to unwrap the pointer to interface{}
	if ptr, ok := orgInfo.(*interface{}); ok {
		// Then try to convert the unwrapped value to map[string]interface{}
		if unwrapped, ok := (*ptr).(map[string]interface{}); ok {
			if org, ok := unwrapped["organization"].(map[string]interface{}); ok {
				orgMap = org
			}
		}
	} else if direct, ok := orgInfo.(map[string]interface{}); ok {
		// Try direct assertion to map[string]interface{}
		if org, ok := direct["organization"].(map[string]interface{}); ok {
			orgMap = org
		}
	}

	if orgMap == nil {
		ghlog.Logger.Error("Could not parse organization data",
			zap.String("type", fmt.Sprintf("%T", orgInfo)))
		return nil, fmt.Errorf("failed to parse organization data")
	}

	return orgMap, nil
}

func createMigrationSource(cmd *cobra.Command, args []string) error {
	ghlog.Logger.Info("Reading input values for creating migration source")

	owner, _ := cmd.Flags().GetString("owner")
	name, _ := cmd.Flags().GetString("name")

	gitLabHost := os.Getenv("GITLAB_HOST")
	if gitLabHost == "" {
		gitLabHost = "https://gitlab.com"
	}
	input := github.MigrationSourceInput{
		Name:    name,
		OwnerID: owner,
		Type:    "GL_EXPORTER_ARCHIVE",
		URL:     gitLabHost,
	}

	migrationSource, err := github.CreateMigrationSource(input)
	if err != nil {
		return fmt.Errorf("failed to create migration source: %v", err)
	}

	ghlog.Logger.Info("Migration source ID: " + fmt.Sprintf("%v", migrationSource.CreateMigrationSource.MigrationSource.ID))
	ghlog.Logger.Info("Migration source name: " + fmt.Sprintf("%v", migrationSource.CreateMigrationSource.MigrationSource.Name))
	ghlog.Logger.Info("Migration source host URL: " + fmt.Sprintf("%v", migrationSource.CreateMigrationSource.MigrationSource.URL))
	ghlog.Logger.Info("Migration source type: " + fmt.Sprintf("%v", migrationSource.CreateMigrationSource.MigrationSource.Type))

	return nil
}

func startMigration(cmd *cobra.Command, args []string) error {
	ghlog.Logger.Info("Reading input values for starting migration")

	migrationSourceID, _ := cmd.Flags().GetString("migration-source-id")
	migrationOwnerId, _ := cmd.Flags().GetString("org-owner-id")
	sourceRepositoryUrl, _ := cmd.Flags().GetString("source-repo")
	archiveUrl, _ := cmd.Flags().GetString("archive-url")
	visibility, err := cmd.Flags().GetString("visibility")

	if err != nil {
		if visibility == "" || visibility == "default" {
			visibility = "private"
			ghlog.Logger.Warn("Invalid visibility, using the default:", zap.String("visibility", visibility))
		} else if visibility != "private" && visibility != "internal" && visibility != "public" {
			visibility = "private"
			ghlog.Logger.Warn("Invalid visibility, using the default:", zap.String("visibility", visibility))
		}
	}

	destinationRepositoryName, _ := cmd.Flags().GetString("repo-name")

	if destinationRepositoryName == "" {
		parts := strings.Split(sourceRepositoryUrl, "/")
		destinationRepositoryName = parts[len(parts)-1]
		ghlog.Logger.Warn("Empty repository name, using the default:", zap.String("repository", destinationRepositoryName))
	}

	input := github.MigrationInput{
		SourceID:             migrationSourceID,
		OwnerID:              migrationOwnerId,
		SourceRepositoryURL:  sourceRepositoryUrl,
		RepositoryName:       destinationRepositoryName,
		ContinueOnError:      true,
		SkipReleases:         false,
		GitArchiveURL:        archiveUrl,
		MetadataArchiveURL:   archiveUrl,
		AccessToken:          "not-used",
		GithubPat:            os.Getenv("GITHUB_PAT"),
		TargetRepoVisibility: visibility,
		LockSource:           false,
	}

	response, err := github.StartMigration(input)
	if err != nil {
		ghlog.Logger.Error("Migration failed",
			zap.String("repository", input.RepositoryName),
			zap.Error(err))
		return nil
	}

	migrationID := response.StartRepositoryMigration.RepositoryMigration.ID
	ghlog.Logger.Info("Migration started",
		zap.String("migration_id", migrationID),
		zap.String("repository", input.RepositoryName))

	status, err := github.VerifyMigrationStatus(migrationID, 60*time.Minute)
	if err != nil {
		ghlog.Logger.Error("Migration verification failed",
			zap.String("migration_id", migrationID),
			zap.Error(err))
		return nil // Return nil to prevent the error from bubbling up
	}

	ghlog.Logger.Info("Migration completed successfully",
		zap.String("repository", status.Node.RepositoryName),
		zap.String("state", status.Node.State))

	return nil
}

func ExportGHECCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "export-ghec",
		Short: "Export repositories from GitHub Enterprise Cloud",
		Long: `Export repositories from GitHub Enterprise Cloud using the migrations API.
        
Requires GITHUB_PAT with appropriate permissions.`,
		Example: `gh glx export-ghec --org my-org --repos repo1,repo2 --lock-repos=false`,
		RunE:    exportGHEC,
	}

	cmd.Flags().String("org", "", "Organization name")
	cmd.Flags().StringSlice("repos", []string{}, "Comma-separated list of repository names")
	cmd.Flags().Bool("lock-repos", false, "Lock repositories during export")
	cmd.Flags().Bool("exclude-git", false, "Exclude Git data from export")
	cmd.Flags().Bool("exclude-releases", false, "Exclude releases from export")
	cmd.Flags().Bool("exclude-metadata", false, "Exclude metadata from export")
	cmd.Flags().String("output", "", "Path where to save the migration archive")

	_ = cmd.MarkFlagRequired("output")
	_ = cmd.MarkFlagRequired("org")
	_ = cmd.MarkFlagRequired("repos")

	return cmd
}

func exportGHEC(cmd *cobra.Command, args []string) error {
	org, _ := cmd.Flags().GetString("org")
	repos, _ := cmd.Flags().GetStringSlice("repos")
	lockRepos, _ := cmd.Flags().GetBool("lock-repos")
	excludeGit, _ := cmd.Flags().GetBool("exclude-git")
	excludeReleases, _ := cmd.Flags().GetBool("exclude-releases")
	excludeMetadata, _ := cmd.Flags().GetBool("exclude-metadata")
	output, _ := cmd.Flags().GetString("output")

	input := github.GHECExportInput{
		Repositories:    repos,
		LockRepos:       lockRepos,
		ExcludeGitData:  excludeGit,
		ExcludeReleases: excludeReleases,
		ExcludeMetadata: excludeMetadata,
		OutputPath:      output,
	}

	export, err := github.ExportRepositories(org, input)
	if err != nil {
		ghlog.Logger.Error("Failed to start export", zap.Error(err))
		return err
	}

	status, err := github.WaitForExportCompletion(org, export.ID, 2*time.Hour, output)
	if err != nil {
		ghlog.Logger.Error("Export failed", zap.Error(err))
		return err
	}

	ghlog.Logger.Info("Export completed successfully",
		zap.String("state", status.State),
		zap.String("url", status.URL))

	return nil
}
