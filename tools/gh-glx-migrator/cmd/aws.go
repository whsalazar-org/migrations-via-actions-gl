package cmd

import (
	"context"
	"fmt"
	"os"
	"time"

	"go.uber.org/zap"

	awsUtils "github.com/ps-resources/gh-glx-migrator/internal/aws"
	"github.com/ps-resources/gh-glx-migrator/internal/clients"
	ghlog "github.com/ps-resources/gh-glx-migrator/pkg/logger"

	"github.com/spf13/cobra"
)

func GeneratePresignedURLCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "generate-aws-presigned-url",
		Short: "Generate a pre-signed URL for S3 archive",
		Long: `Generate a pre-signed URL for accessing objects in an S3 bucket.

The URL will expire after the specified duration (default 15 minutes).
AWS credentials must be configured via environment variables.`,
		Example: `  gh glx generate-aws-presigned-url --bucket my-bucket --blob-name archive.tar.gz
gh glx generate-aws-presigned-url --bucket my-bucket --duration 30m`,
		RunE: generatePresignedURL,
	}

	cmd.Flags().String("bucket", os.Getenv("AWS_BUCKET"), "S3 bucket name")
	cmd.Flags().String("blob-name", "", "Name to use for blob in AWS (defaults to local file name)")
	cmd.Flags().Duration("duration", 30*time.Minute, "URL validity duration (default 30 minutes)")

	return cmd
}

func UploadToS3BucketCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "upload-to-s3",
		Short: "Upload a file to an S3 bucket",
		Long: `Upload the extracted archive to an S3 bucket.

The file will be uploaded to the specified bucket and blob-name.
AWS credentials must be configured via environment variables.`,

		Example: `  gh glx upload-to-s3 --bucket my-bucket --blob-name archive.tar.gz --archive-file-path archive.tar.gz`,
		RunE:    uploadToS3Bucket,
	}

	cmd.Flags().String("blob-name", "", "Name to use for blob in AWS (defaults to local file name)")
	cmd.Flags().String("archive-file-path", "", "Path to migration archive file")
	cmd.Flags().String("bucket", os.Getenv("AWS_BUCKET"), "S3 bucket name")

	errFile := cmd.MarkFlagRequired("archive-file-path")
	if errFile != nil {
		ghlog.Logger.Error("failed to mark flag as required", zap.Error(errFile))
		return nil
	}

	return cmd
}
func generatePresignedURL(cmd *cobra.Command, args []string) error {
	// Verify required AWS environment variables on startup
	if err := verifyAws(); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
	ghlog.Logger.Info("Reading input values for generating pre-signed URL")

	bucket, _ := cmd.Flags().GetString("bucket")
	blobName, _ := cmd.Flags().GetString("blob-name")
	duration, _ := cmd.Flags().GetDuration("duration")

	if bucket == "" {
		return fmt.Errorf("bucket name is required. Please provide it using --bucket flag or set it in the environment variable AWS_BUCKET")
	}

	ctx, cancel := context.WithTimeout(cmd.Context(), 2*time.Minute)
	defer cancel()

	awsClient := clients.NewAwsClient()
	s3Manager, err := awsUtils.NewS3Manager(ctx, awsClient, bucket)

	if err != nil {
		ghlog.Logger.Error("failed to create S3Manager", zap.Error(err))
		return fmt.Errorf("failed to initialize AWS S3 manager: %w", err)
	}

	// Generate presigned URL using the manager
	url, err := s3Manager.GeneratePresignedURL(ctx, blobName, duration)
	if err != nil {
		return fmt.Errorf("failed to generate presigned URL: %w", err)
	}

	ghlog.Logger.Info("Generated pre-signed URL S3 Successfully")
	ghlog.Logger.Info("Pre-signed URL", zap.String("url", url))
	ghlog.Logger.Info("URL will expire at", zap.Time("expiration", time.Now().Add(duration)))

	return nil
}

func uploadToS3Bucket(cmd *cobra.Command, args []string) error {
	// Verify required AWS environment variables on startup
	if err := verifyAws(); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
	ghlog.Logger.Info("Reading input values for uploading to S3 bucket")
	bucket, _ := cmd.Flags().GetString("bucket")
	blobName, _ := cmd.Flags().GetString("blob-name")
	archiveFilePath, _ := cmd.Flags().GetString("archive-file-path")

	if bucket == "" {
		return fmt.Errorf("bucket name is required. Please provide it using --bucket flag or set it in the environment variable AWS_BUCKET")
	}

	ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Minute)
	defer cancel()

	// Open the file
	file, err := os.Open(archiveFilePath)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}
	defer func() {
		if err := file.Close(); err != nil {
			ghlog.Logger.Error("failed to close file", zap.Error(err))
		}
	}()

	ghlog.Logger.Info("Uploading file to S3 bucket",
		zap.String("bucket", bucket),
		zap.String("blobName", blobName),
		zap.String("archive-file-path", archiveFilePath))

	// Create AWS client
	awsClient := clients.NewAwsClient()

	// Create S3Manager
	s3Manager, err := awsUtils.NewS3Manager(ctx, awsClient, bucket)
	if err != nil {
		ghlog.Logger.Error("failed to create S3Manager", zap.Error(err))
		return fmt.Errorf("failed to initialize AWS S3 manager: %w", err)
	}

	// s3Manager.SetPartSize(200 * 1024 * 1024) // 200MB parts

	if err := s3Manager.Upload(ctx, blobName, file); err != nil {
		return fmt.Errorf("failed to upload to S3 bucket: %w", err)
	}

	ghlog.Logger.Info("File uploaded successfully",
		zap.String("bucket", bucket),
		zap.String("blobName", blobName))
	return nil
}
