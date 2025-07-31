package github

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"github.com/ps-resources/gh-glx-migrator/pkg/logger"

	"go.uber.org/zap"
)

func ExportRepositories(orgName string, input GHECExportInput) (*GHECExportResponse, error) {
	logger.Logger.Info("Starting GHEC repository export",
		zap.String("organization", orgName),
		zap.Strings("repositories", input.Repositories))

	githubToken := os.Getenv("GITHUB_GHEC_PAT")
	githubHost := os.Getenv("GITHUB_GHEC_API_ENDPOINT")
	if githubHost == "" {
		githubHost = "api.github.com" // Default to api.github.com if not set
	}
	if githubToken == "" {
		logger.Logger.Error("Missing required environment variable",
			zap.String("variable", "GITHUB_GHEC_PAT"))
		return nil, fmt.Errorf("GITHUB_GHEC_PAT environment variable is required")
	}

	url := fmt.Sprintf("https://%s/orgs/%s/migrations", githubHost, orgName)

	jsonBody, err := json.Marshal(input)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request body: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Update headers for GHEC API
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("Authorization", fmt.Sprintf("token %s", githubToken))
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	req.Header.Set("User-Agent", "gh-glx-migrator")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to make request: %w", err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			logger.Logger.Error("failed to close response body", zap.Error(err))
		}
	}()

	// Read response body for better error messages
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusAccepted {
		var errorResponse struct {
			Message       string `json:"message"`
			Documentation string `json:"documentation_url"`
		}
		if err := json.Unmarshal(body, &errorResponse); err != nil {
			return nil, fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(body))
		}
		logger.Logger.Error("GitHub API error",
			zap.Int("status_code", resp.StatusCode),
			zap.String("message", errorResponse.Message),
			zap.String("documentation", errorResponse.Documentation))
		return nil, fmt.Errorf("GitHub API error: %s", errorResponse.Message)
	}

	var exportResp GHECExportResponse
	if err := json.Unmarshal(body, &exportResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	logger.Logger.Info("Export started successfully",
		zap.Int64("migration_id", exportResp.ID),
		zap.String("state", exportResp.State),
		zap.String("url", exportResp.URL))

	return &exportResp, nil
}

func GetExportStatus(orgName string, migrationId int64) (*GHECExportResponse, error) {
	githubToken := os.Getenv("GITHUB_GHEC_PAT")
	githubHost := "api.github.com" // GHEC always uses api.github.com

	if githubToken == "" {
		logger.Logger.Error("Missing required environment variable",
			zap.String("variable", "GITHUB_GHEC_PAT"))
		return nil, fmt.Errorf("GITHUB_GHEC_PAT environment variable is required")
	}

	url := fmt.Sprintf("https://%s/orgs/%s/migrations/%d", githubHost, orgName, migrationId)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Update headers for GHEC API
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("Authorization", fmt.Sprintf("token %s", githubToken))
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	req.Header.Set("User-Agent", "gh-glx-migrator")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to make request: %w", err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			logger.Logger.Error("failed to close response body", zap.Error(err))
		}
	}()

	// Read response body for better error messages
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		var errorResponse struct {
			Message       string `json:"message"`
			Documentation string `json:"documentation_url"`
		}
		if err := json.Unmarshal(body, &errorResponse); err != nil {
			return nil, fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(body))
		}
		logger.Logger.Error("GitHub API error",
			zap.Int("status_code", resp.StatusCode),
			zap.String("message", errorResponse.Message),
			zap.String("documentation", errorResponse.Documentation))
		return nil, fmt.Errorf("GitHub API error: %s", errorResponse.Message)
	}

	var status GHECExportResponse
	if err := json.Unmarshal(body, &status); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w, body: %s", err, string(body))
	}

	return &status, nil
}

func WaitForExportCompletion(orgName string, migrationId int64, timeout time.Duration, outputPath string) (*GHECExportResponse, error) {
	logger.Logger.Info("Waiting for export to complete",
		zap.String("organization", orgName),
		zap.Int64("migration_id", migrationId))

	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	timeoutChan := time.After(timeout)

	for {
		select {
		case <-timeoutChan:
			return nil, fmt.Errorf("timeout waiting for export to complete")
		case <-ticker.C:
			status, err := GetExportStatus(orgName, migrationId)
			if err != nil {
				return nil, err
			}

			logger.Logger.Info("Export status",
				zap.String("state", status.State),
				zap.String("url", status.URL))

			switch status.State {
			case "exported":
				if err := DownloadExportArchive(orgName, migrationId, outputPath); err != nil {
					return nil, fmt.Errorf("failed to download archive: %w", err)
				}
				return status, nil
			case "failed":
				return nil, fmt.Errorf("export failed")
			}
		}
	}
}

// DownloadExportArchive downloads the migration archive to the specified path
func DownloadExportArchive(orgName string, migrationId int64, outputPath string) error {
	githubToken := os.Getenv("GITHUB_GHEC_PAT")
	githubHost := "api.github.com"

	url := fmt.Sprintf("https://%s/orgs/%s/migrations/%d/archive", githubHost, orgName, migrationId)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("Authorization", fmt.Sprintf("token %s", githubToken))
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	req.Header.Set("User-Agent", "gh-glx-migrator")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to download archive: %w", err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			logger.Logger.Error("failed to close response body", zap.Error(err))
		}
	}()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("failed to download archive: status %d: %s", resp.StatusCode, string(body))
	}

	out, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create output file: %w", err)
	}
	defer func() {
		if err := out.Close(); err != nil {
			logger.Logger.Error("failed to close output file", zap.Error(err))
		}
	}()

	logger.Logger.Info("Downloading migration archive",
		zap.String("organization", orgName),
		zap.Int64("migration_id", migrationId),
		zap.String("output_path", outputPath))

	_, err = io.Copy(out, resp.Body)
	if err != nil {
		return fmt.Errorf("failed to save archive: %w", err)
	}

	logger.Logger.Info("Successfully downloaded migration archive",
		zap.String("path", outputPath))

	return nil
}
