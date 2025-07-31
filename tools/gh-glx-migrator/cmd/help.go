package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

func HelpCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "help",
		Short: "Help about the gh-glx commands",
		Long: `gh-glx is a CLI tool for migrating repositories from GitLab to GitHub Enterprise Cloud with Data Residency.

Required Environment Variables:
GITHUB_PAT                  GitHub Personal Access Token
GITHUB_API_ENDPOINT         GitHub Enterprise URL (e.g., github.example.com)
GITHUB_ORG                  GitHub Organization name
GITLAB_PAT                  GitLab Personal Access Token
GITLAB_API_ENDPOINT         GitLab API endpoint (e.g., gitlab.com/api/v4)
GITLAB_USERNAME             GitLab username
GITLAB_HOST                 GitLab URL (e.g., gitlab.com)
AWS_ACCESS_KEY_ID           AWS Access Key for S3
AWS_SECRET_ACCESS_KEY       AWS Secret Key for S3
AWS_REGION                  AWS Region (e.g., us-west-2)
AWS_BUCKET                  S3 Bucket name (optional)

Available Commands:
verify                      Verify configuration and credentials
generate-aws-presigned-url  Generate pre-signed URL for S3 archive
upload-to-s3                Upload a file to S3 bucket
export-archive              Export GitLab repository as archive
get-org-info                Get GitHub organization information
create-migration-source     Create migration source for GitLab
migrate                     Start repository migration
migrate-repo                Perform complete repository migration
help                        Show this help message

Examples:
# Verify configuration
gh glx verify

# Generate pre-signed URL for S3 archive
gh glx generate-aws-presigned-url --bucket my-bucket --key archive.tar.gz --duration 30m

# Upload file to S3
gh glx upload-to-s3 --bucket my-bucket --key archive.tar.gz --file-path ./archive.tar.gz

# Export GitLab repository
gh glx export-archive --gl-project group/project --output-file archive.tar.gz

# Get GitHub organization info
gh glx get-org-info --org my-organization

# Create migration source
gh glx create-migration-source --owner O_xxx --name "GitLab Migration"

# Start migration
gh glx migrate \
  --migration-source-id MS_xxx \
  --org-owner-id O_xxx \
  --source-repo https://gitlab.com/org/repo \
  --archive-url https://s3.amazonaws.com/archive.tar.gz \
  --visibility private \
  --repo-name new-repo

# Full repository migration
gh glx migrate-repo \
  --gl-project group/project \
  --bucket my-bucket \
  --org my-org \
  --visibility private \
  --repo-name new-repo`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println(cmd.Long)
		},
	}
}
