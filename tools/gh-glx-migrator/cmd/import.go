package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	awsUtils "github.com/ps-resources/gh-glx-migrator/internal/aws"
	"github.com/ps-resources/gh-glx-migrator/internal/azure"
	"github.com/ps-resources/gh-glx-migrator/internal/clients"
	"github.com/ps-resources/gh-glx-migrator/internal/github"
	ghlog "github.com/ps-resources/gh-glx-migrator/pkg/logger"

	"github.com/spf13/cobra"
	"go.uber.org/zap"
)

func ImportArchiveCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "import-archive",
		Short: "Import a gitlab archive to GitHub",
		Long: `Import a gitlab archive to GitHub start to finish.
			
GitHub credentials must be configured via environment variables.`,
		Example: `gh glx import-archive --bucket s3bucket --blob-name migration_archive.tar.gz --org org --source-repo https://gitlab.com/org/repo --visibility private --repo-name my-repo`,
		RunE:    importArchive,
	}

	//cmd.Flags().String("archive", "migration_archive.tar.gz", "Migration archive file")
	cmd.Flags().String("bucket", os.Getenv("AWS_BUCKET"), "S3 bucket name")
	cmd.Flags().String("blob-name", "", "Name to use for blob in S3 or Azure (defaults to local file name)")
	cmd.Flags().String("archive-file-path", "", "Path to migration archive file")
	cmd.Flags().Duration("duration", 20*time.Minute, "Duration for the presigned URL in minutes")
	cmd.Flags().String("org", "", "GitHub organization to import to")
	cmd.Flags().String("source-repo", "", "GitLab source repository URL")
	cmd.Flags().String("visibility", "private", "Visibility of the new repository (public, private, internal)")
	cmd.Flags().String("repo-name", "", "Name of the new repository")

	errOrg := cmd.MarkFlagRequired("org")
	if errOrg != nil {
		ghlog.Logger.Error("failed to mark flag as required", zap.Error(errOrg))
		return nil
	}
	errFile := cmd.MarkFlagRequired("archive-file-path")
	if errFile != nil {
		ghlog.Logger.Error("failed to mark flag as required", zap.Error(errFile))
		return nil
	}
	errSourceRepo := cmd.MarkFlagRequired("source-repo")
	if errSourceRepo != nil {
		ghlog.Logger.Error("failed to mark flag as required", zap.Error(errSourceRepo))
		return nil
	}

	return cmd
}

func importArchive(cmd *cobra.Command, args []string) error {
	// Verify required environment variables on startup
	if err := VerifyRequiredEnvVars(); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
	ghlog.Logger.Info("Reading input values for starting migration")
	org, _ := cmd.Flags().GetString("org")
	sourceRepositoryUrl, _ := cmd.Flags().GetString("source-repo")
	visibility, _ := cmd.Flags().GetString("visibility")
	destinationRepositoryName, _ := cmd.Flags().GetString("repo-name")
	bucket, _ := cmd.Flags().GetString("bucket")
	blobName, _ := cmd.Flags().GetString("blob-name")
	duration, _ := cmd.Flags().GetDuration("duration")
	archiveFilePath, _ := cmd.Flags().GetString("archive-file-path")

	awsAccessKeyId := os.Getenv("AWS_ACCESS_KEY_ID")
	awsSecretAccessKey := os.Getenv("AWS_SECRET_ACCESS_KEY")

	azureStorageAccount := os.Getenv("AZURE_STORAGE_ACCOUNT")
	azureStorageAccessKey := os.Getenv("AZURE_STORAGE_ACCESS_KEY")

	blobStorageAws := false
	blobStorageAzure := false
	blobStorageGithub := false

	if awsAccessKeyId != "" && awsSecretAccessKey != "" {
		if bucket == "" {
			return fmt.Errorf("bucket name is required when using AWS storage. Please provide it using --bucket flag or set it in the environment variable AWS_BUCKET")
		} else {
			blobStorageAws = true
		}
	} else if azureStorageAccount != "" && azureStorageAccessKey != "" {
		blobStorageAzure = true
	} else {
		blobStorageGithub = true
	}

	if blobName == "" {
		blobName = filepath.Base(archiveFilePath)
	}

	if destinationRepositoryName == "" {
		parts := strings.Split(sourceRepositoryUrl, "/")
		destinationRepositoryName = parts[len(parts)-1]
	}

	ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Minute)
	defer cancel()

	var presignedUrl string
	var err error
	awsClient := clients.NewAwsClient()

	if blobStorageAws {
		s3Manager, err := awsUtils.NewS3Manager(ctx, awsClient, bucket)
		if err != nil {
			ghlog.Logger.Error("failed to create S3Manager", zap.Error(err))
			return fmt.Errorf("failed to initialize AWS S3 manager: %w", err)
		}
		presignedUrl, err = uploadToS3AndGeneratePresignedURL(ctx, s3Manager, bucket, archiveFilePath, blobName, duration)
		if err != nil {
			return err
		}
	}

	if blobStorageAzure {
		// upload to Azure Blob Storage and return presigned URL
		presignedUrl, err = uploadToAzureStorageAndGeneratePresignedURL(bucket, archiveFilePath, blobName, duration)
		if err != nil {
			ghlog.Logger.Error("failed to upload to Azure Blob Storage", zap.Error(err))
			return fmt.Errorf("failed to upload to Azure Blob Storage: %w", err)
		}
	}

	orgMap, err := fetchOrgInfo(org)
	if err != nil {
		return fmt.Errorf("failed to fetch organization information: %w", err)
	}

	var orgId = orgMap["id"]
	var orgDatabaseId = orgMap["databaseId"]
	// convert orgDatabaseId to int
	orgDatabaseId = int(orgDatabaseId.(float64))
	// convert orgDatabaseId to string
	orgDatabaseId = fmt.Sprintf("%v", orgDatabaseId)
	ghlog.Logger.Info("orgId: " + fmt.Sprintf("%v", orgId))

	if blobStorageGithub {
		// upload to GitHub storage
		uploadArchiveInput := github.UploadArchiveInput{
			ArchiveFilePath: archiveFilePath,
			OrganizationId:  orgDatabaseId.(string),
		}

		presignedUrl, err = github.UploadArchiveToGitHub(ctx, uploadArchiveInput)
		if err != nil {
			ghlog.Logger.Error("failed to upload to GitHub storage", zap.Error(err))
			return fmt.Errorf("failed to upload to GitHub storage: %w", err)
		}
		ghlog.Logger.Info("Uploaded archive to GitHub storage successfully")
		ghlog.Logger.Info("URL: " + presignedUrl)
	}

	gitLabHost := os.Getenv("GITLAB_HOST")
	if gitLabHost == "" {
		gitLabHost = "https://gitlab.com"
	}
	migrationSourceInput := github.MigrationSourceInput{
		Name:    "GitLab Archive Migration",
		OwnerID: orgId.(string),
		Type:    "GL_EXPORTER_ARCHIVE",
		URL:     gitLabHost,
	}

	migrationSource, err := github.CreateMigrationSource(migrationSourceInput)
	if err != nil {
		return fmt.Errorf("failed to create migration source: %w", err)
	}

	ghlog.Logger.Info("Migration source ID: " + fmt.Sprintf("%v", migrationSource.CreateMigrationSource.MigrationSource.ID))

	var migrationSourceId = migrationSource.CreateMigrationSource.MigrationSource.ID

	migrationInput := github.MigrationInput{
		SourceID:             migrationSourceId,
		OwnerID:              orgId.(string),
		SourceRepositoryURL:  sourceRepositoryUrl,
		RepositoryName:       destinationRepositoryName,
		ContinueOnError:      true,
		SkipReleases:         false,
		GitArchiveURL:        presignedUrl,
		MetadataArchiveURL:   presignedUrl,
		AccessToken:          "not-used",
		GithubPat:            os.Getenv("GITHUB_PAT"),
		TargetRepoVisibility: visibility,
		LockSource:           false,
	}

	response, err := github.StartMigration(migrationInput)
	if err != nil {
		ghlog.Logger.Error("Starting Migration failed",
			zap.String("repository", migrationInput.RepositoryName),
			zap.Error(err))
		return err
	}

	migrationID := response.StartRepositoryMigration.RepositoryMigration.ID
	ghlog.Logger.Info("Migration started",
		zap.String("migration_id", migrationID),
		zap.String("repository", migrationInput.RepositoryName))

	status, err := github.VerifyMigrationStatus(migrationID, 90*time.Minute)
	if err != nil {
		ghlog.Logger.Error("Migration verification failed",
			zap.String("migration_id", migrationID),
			zap.Error(err))
		return nil
	}

	ghlog.Logger.Info("Migration completed successfully",
		zap.String("repository", status.Node.RepositoryName),
		zap.String("state", status.Node.State))

	if blobStorageAws {
		// Initialize s3Manager before using it
		s3Manager, err := awsUtils.NewS3Manager(ctx, awsClient, bucket)
		if err != nil {
			ghlog.Logger.Error("failed to create S3Manager", zap.Error(err))
			return fmt.Errorf("failed to initialize AWS S3 manager: %w", err)
		}

		if err := s3Manager.DeleteObject(ctx, blobName); err != nil {
			ghlog.Logger.Error("failed to delete file from S3", zap.Error(err))
			return fmt.Errorf("failed to delete file from S3: %w", err)
		}
		ghlog.Logger.Info("Deleted file from S3 bucket", zap.String("bucket", bucket), zap.String("key", blobName))
	}

	if blobStorageAzure {
		storageAccount := os.Getenv("AZURE_STORAGE_ACCOUNT")
		storageAccessKey := os.Getenv("AZURE_STORAGE_ACCESS_KEY")
		opts := &azure.AzureOptions{
			StorageAccount:   storageAccount,
			StorageAccessKey: storageAccessKey,
			ContainerName:    bucket,
			BlobName:         blobName,
			ArchiveFilePath:  archiveFilePath,
		}
		err = azure.DeleteBlob(opts)
		if err != nil {
			ghlog.Logger.Error("failed to delete file from Azure Blob Storage", zap.Error(err))
			return fmt.Errorf("failed to delete file from Azure Blob Storage: %w", err)
		}
		ghlog.Logger.Info("Deleted file from Azure Blob Storage", zap.String("container", bucket), zap.String("blob", blobName))
	}
	ghlog.Logger.Info("Migration completed successfully",
		zap.String("repository", status.Node.RepositoryName),
		zap.String("state", status.Node.State))

	return nil
}

func uploadToS3AndGeneratePresignedURL(ctx context.Context, s3Manager *awsUtils.S3Manager, bucket, archiveFilePath, blobName string, duration time.Duration) (string, error) {
	file, err := os.Open(archiveFilePath)
	if err != nil {
		return "", fmt.Errorf("failed to open file: %w", err)
	}
	defer func() {
		if err := file.Close(); err != nil {
			ghlog.Logger.Error("failed to close file", zap.Error(err))
		}
	}()

	ghlog.Logger.Info("Uploading to S3 bucket",
		zap.String("bucket", bucket),
		zap.String("key", blobName),
		zap.String("file-path", archiveFilePath))

	if err := s3Manager.Upload(ctx, blobName, file); err != nil {
		return "", fmt.Errorf("failed to upload to S3 bucket: %w", err)
	}

	presignedUrl, err := s3Manager.GeneratePresignedURL(ctx, blobName, duration)
	if err != nil {
		ghlog.Logger.Error("failed to generate pre-signed URL", zap.Error(err))
		return "", fmt.Errorf("failed to generate presigned URL: %w", err)
	}

	ghlog.Logger.Info("Generated pre-signed URL S3 Successfully")
	ghlog.Logger.Info("Pre-signed URL", zap.String("url", presignedUrl))
	ghlog.Logger.Info("URL will expire at", zap.Time("expiration", time.Now().Add(duration)))

	return presignedUrl, nil
}

func uploadToAzureStorageAndGeneratePresignedURL(bucket, archiveFilePath, blobName string, duration time.Duration) (string, error) {
	// Get Azure credentials from environment
	storageAccount := os.Getenv("AZURE_STORAGE_ACCOUNT")
	storageAccessKey := os.Getenv("AZURE_STORAGE_ACCESS_KEY")

	opts := &azure.AzureOptions{
		StorageAccount:   storageAccount,
		StorageAccessKey: storageAccessKey,
		ContainerName:    bucket,
		BlobName:         blobName,
		ArchiveFilePath:  archiveFilePath,
	}

	ghlog.Logger.Info("Uploading file to Azure Blob Storage",
		zap.String("file", archiveFilePath),
		zap.String("container", bucket))

	presignedUrl, err := azure.UploadToAzureBlob(opts, duration)
	if err != nil {
		ghlog.Logger.Error("Failed to upload file to Azure", zap.Error(err))
		return "", fmt.Errorf("failed to upload file to Azure: %v", err)
	}

	ghlog.Logger.Info("File uploaded successfully")
	ghlog.Logger.Info("Presigned URL: " + presignedUrl)

	return presignedUrl, nil
}
