package cmd

import (
	"fmt"
	"os"
	"time"

	"github.com/ps-resources/gh-glx-migrator/internal/azure"
	ghlog "github.com/ps-resources/gh-glx-migrator/pkg/logger"

	"github.com/spf13/cobra"
	"go.uber.org/zap"
)

// UploadToAzureCmd returns a command to upload a file to Azure Blob Storage
func UploadToAzureCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "upload-to-azure",
		Short: "Upload a file to Azure Blob Storage",
		Long: `Upload a file to Azure Blob Storage and generate a presigned URL.
        
Azure credentials must be set via environment variables:
- AZURE_STORAGE_ACCOUNT: Azure storage account name
- AZURE_STORAGE_ACCESS_KEY: Azure storage account access key`,
		Example: `gh glx-migrator upload-to-azure --archiveFilePath path/to/file.zip --container my-container --blob-name my-blob`,
		RunE:    runUploadToAzure,
	}

	cmd.Flags().String("archive-file-path", "", "Path to migration archive file")
	cmd.Flags().String("container", "", "Azure Blob Storage container name")
	cmd.Flags().String("blob-name", "", "Name to use for blob in Azure (defaults to local file name)")
	cmd.Flags().Duration("duration", 30*time.Minute, "URL validity duration (default 30 minutes)")

	_ = cmd.MarkFlagRequired("archive-file-path")
	_ = cmd.MarkFlagRequired("container")

	return cmd
}

func runUploadToAzure(cmd *cobra.Command, args []string) error {
	// Verify required Azure environment variables on startup
	if err := verifyAzure(); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
	ghlog.Logger.Info("Reading input values for uploading to Azure Blob Storage")

	archiveFilePath, _ := cmd.Flags().GetString("archive-file-path")
	containerName, _ := cmd.Flags().GetString("container")
	blobName, _ := cmd.Flags().GetString("blob-name")
	duration, _ := cmd.Flags().GetDuration("duration")

	// Get Azure credentials from environment
	storageAccount := os.Getenv("AZURE_STORAGE_ACCOUNT")
	storageAccessKey := os.Getenv("AZURE_STORAGE_ACCESS_KEY")

	if storageAccount == "" || storageAccessKey == "" {
		return fmt.Errorf("AZURE_STORAGE_ACCOUNT and AZURE_STORAGE_ACCESS_KEY environment variables must be set")
	}

	opts := &azure.AzureOptions{
		StorageAccount:   storageAccount,
		StorageAccessKey: storageAccessKey,
		ContainerName:    containerName,
		BlobName:         blobName,
		ArchiveFilePath:  archiveFilePath,
	}

	ghlog.Logger.Info("Uploading file to Azure Blob Storage",
		zap.String("container", containerName),
		zap.String("blobName", blobName),
		zap.String("archive-file-path", archiveFilePath))

	presignedURL, err := azure.UploadToAzureBlob(opts, duration)
	if err != nil {
		ghlog.Logger.Error("Failed to upload file to Azure", zap.Error(err))
		return fmt.Errorf("failed to upload file to Azure: %v", err)
	}

	ghlog.Logger.Info("File uploaded successfully")
	ghlog.Logger.Info("Presigned URL: " + presignedURL)

	return nil
}
