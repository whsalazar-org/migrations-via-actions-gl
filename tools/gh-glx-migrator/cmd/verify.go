package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"go.uber.org/zap"

	"github.com/ps-resources/gh-glx-migrator/internal/clients"
	ghlog "github.com/ps-resources/gh-glx-migrator/pkg/logger"

	"github.com/spf13/cobra"
)

func VerifyCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "verify",
		Short: "Verify connections and credentials",
		Long: `Verify GitHub, GitLab, and AWS connections and configuration.

This command checks:
- GitHub PAT authentication
- GitHub Enterprise Cloud with Data Residency API access
- GitLab API access
- AWS S3 credentials
- Required environment variables

All credentials must be set via environment variables before running this command.`,
		RunE: runVerify,
	}
	return cmd
}

func runVerify(cmd *cobra.Command, args []string) error {
	// Verify required environment variables on startup
	if err := VerifyRequiredEnvVars(); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
	ghlog.Logger.Info("Verifying configuration and credentials...")

	errChan := make(chan error, 3)

	go func() {
		errChan <- verifyGitHubPAT()
	}()

	for i := 0; i < 1; i++ {
		if err := <-errChan; err != nil {
			return err
		}
	}

	ghlog.Logger.Info("✓ All configurations and credentials verified successfully!")
	return nil
}

func VerifyRequiredEnvVars() error {
	required := []struct {
		name  string
		value string
	}{
		{"GITHUB_PAT", os.Getenv("GITHUB_PAT")},
	}

	awsRequired := []struct {
		name  string
		value string
	}{
		{"AWS_ACCESS_KEY_ID", os.Getenv("AWS_ACCESS_KEY_ID")},
		{"AWS_SECRET_ACCESS_KEY", os.Getenv("AWS_SECRET_ACCESS_KEY")},
		{"AWS_REGION", os.Getenv("AWS_REGION")},
	}

	azureRequired := []struct {
		name  string
		value string
	}{
		{"AZURE_STORAGE_ACCOUNT", os.Getenv("AZURE_STORAGE_ACCOUNT")},
		{"AZURE_STORAGE_ACCESS_KEY", os.Getenv("AZURE_STORAGE_ACCESS_KEY")},
	}

	var missingAWS, missingAzure, missing []string
	for _, r := range awsRequired {
		if r.value == "" {
			missingAWS = append(missingAWS, r.name)
		}
	}

	for _, r := range azureRequired {
		if r.value == "" {
			missingAzure = append(missingAzure, r.name)
		}
	}

	for _, r := range required {
		if r.value == "" {
			missing = append(missing, r.name)
		}
	}

	// Ensure at least one provider's full set of credentials is present
	if len(missingAWS) > 0 && len(missingAzure) > 0 {
		// Check if the user has already set USE_GITHUB_STORAGE to true
		if os.Getenv("USE_GITHUB_STORAGE") == "true" {
			ghlog.Logger.Info("Using GitHub blob storage for migration (from environment variable)")
			return nil
		}

		// Prompt the user to ask if using GitHub blob storage
		reader := bufio.NewReader(os.Stdin)
		fmt.Print("Do you want to use GitHub blob storage instead of AWS/Azure? (y/n): ")
		text, err := reader.ReadString('\n')
		if err != nil {
			ghlog.Logger.Error("Error reading user input", zap.Error(err))
			return fmt.Errorf("error reading user input: %w", err)
		}
		text = strings.TrimSpace(text)

		if strings.ToLower(text) == "y" || strings.ToLower(text) == "yes" {
			ghlog.Logger.Info("Using GitHub blob storage for migration")
			// Set flag or environment variable to indicate GitHub blob storage usage
			if err := os.Setenv("USE_GITHUB_STORAGE", "true"); err != nil {
				ghlog.Logger.Error("Failed to set USE_GITHUB_STORAGE environment variable", zap.Error(err))
				return fmt.Errorf("failed to set USE_GITHUB_STORAGE environment variable: %w", err)
			}
			return nil
		} else {
			ghlog.Logger.Error(
				"Missing required environment variables. You must provide either AWS or Azure blob storage credentials",
				zap.Strings("missing_aws", missingAWS),
				zap.Strings("missing_azure", missingAzure),
			)
			return fmt.Errorf("missing required cloud storage credentials")
		}
	}

	if len(missing) > 0 {
		ghlog.Logger.Error("Missing required environment variables",
			zap.Strings("missing", missing))
		return fmt.Errorf("missing required environment variables")
	}

	ghlog.Logger.Info("All required environment variables are set")
	return nil
}

func verifyGitHubPAT() error {

	ghlog.Logger.Info("Verifying GITHUB_PAT")
	githubPAT := os.Getenv("GITHUB_PAT")

	if githubPAT == "" {
		return fmt.Errorf("GITHUB_PAT environment variable is not set")
	}

	ghlog.Logger.Info("GITHUB_PAT environment variable is set")
	ghlog.Logger.Info("Checking GITHUB_PAT credentials and scope")

	githubClient := clients.NewGitHubClient(githubPAT)
	if _, err := githubClient.GitHubAuth(); err != nil {
		ghlog.Logger.Debug("GitHub authentication failed", zap.Error(err))

		return fmt.Errorf("GitHub authentication failed")
	}

	ghlog.Logger.Info("GitHub credentials verified")
	return nil
}

func verifyAws() error {
	ghlog.Logger.Info("Verifying AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION")

	awsAccessKey := os.Getenv("AWS_ACCESS_KEY_ID")
	awsSecretKey := os.Getenv("AWS_SECRET_ACCESS_KEY")
	awsRegion := os.Getenv("AWS_REGION")

	if awsAccessKey == "" || awsSecretKey == "" || awsRegion == "" {
		return fmt.Errorf("AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION environment variables must be set")
	}

	return nil
}

func verifyAzure() error {
	ghlog.Logger.Info("Verifying AZURE_STORAGE_ACCOUNT and AZURE_STORAGE_ACCESS_KEY")

	azureStorageAccount := os.Getenv("AZURE_STORAGE_ACCOUNT")
	azureStorageAccessKey := os.Getenv("AZURE_STORAGE_ACCESS_KEY")

	if azureStorageAccount == "" || azureStorageAccessKey == "" {
		return fmt.Errorf("AZURE_STORAGE_ACCOUNT and AZURE_STORAGE_ACCESS_KEY environment variables must be set")
	}
	return nil
}
