package github

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/ps-resources/gh-glx-migrator/internal/clients"
	ghlog "github.com/ps-resources/gh-glx-migrator/pkg/logger"

	"github.com/cheggaaa/pb/v3"
	"go.uber.org/zap"
)

const (
	DefaultPartSize           int64 = 100 * 1024 * 1024  // 100 MB
	DefaultMultipartThreshold int64 = 5000 * 1024 * 1024 // 5 GB
)

func GetOrgInfo(orgName string) (interface{}, error) {
	ghlog.Logger.Info("Getting organization information from GitHub")

	// Get environment variables
	githubToken := os.Getenv("GITHUB_PAT")
	githubHost := os.Getenv("GITHUB_API_ENDPOINT")

	if githubHost == "" {
		githubHost = "api.github.com"
	}

	githubClient := clients.NewGitHubClient(githubToken)
	client, err := githubClient.GitHubAuth()

	if err != nil {
		return nil, fmt.Errorf("failed to create GitHub client: %v", err)
	}

	query := `
	query($login: String!) {
			organization(login: $login) {
					login
					id
					name
					databaseId
			}
	}`

	requestBody := map[string]interface{}{
		"query": query,
		"variables": QueryVariables{
			Login: orgName,
		},
	}

	jsonBody, err := json.Marshal(requestBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request body: %v", err)
	}

	url := fmt.Sprintf("https://%s/graphql", githubHost)

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create HTTP request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "gh-glx-migrator")

	resp, err := client.Client().Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to make GraphQL request: %v", err)
	}

	// if the response status is not 200, show error message
	// and the response body and return an error
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected response status: %d, body: %s", resp.StatusCode, func() string {
			body, _ := io.ReadAll(resp.Body)
			return string(body)
		}())
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			ghlog.Logger.Error("failed to close response body", zap.Error(err))
		}
	}()

	// Parse the response
	var response GraphQLResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, fmt.Errorf("failed to decode response: %v", err)
	}

	// Check for GraphQL errors
	if len(response.Errors) > 0 {
		errMsg := response.Errors[0].Message
		return nil, fmt.Errorf("GraphQL error: %s", errMsg)
	}

	ghlog.Logger.Info("Successfully retrieved organization information",
		zap.String("organization", orgName))

	return &response.Data, nil
}

func UploadArchiveToGitHub(ctx context.Context, input UploadArchiveInput) (string, error) {
	archiveFilePath := input.ArchiveFilePath
	orgId := input.OrganizationId

	// Open the file
	reader, err := os.Open(archiveFilePath)
	if err != nil {
		return "", fmt.Errorf("failed to open file: %w", err)
	}

	currentPos, err := reader.Seek(0, io.SeekCurrent)
	if err != nil {
		return "", logAndReturnError(archiveFilePath, fmt.Errorf("failed to get current position: %w", err))
	}

	size, err := reader.Seek(0, io.SeekEnd)
	if err != nil {
		return "", logAndReturnError(archiveFilePath, fmt.Errorf("failed to determine file size: %w", err))
	}

	_, err = reader.Seek(currentPos, io.SeekStart)
	if err != nil {
		return "", logAndReturnError(archiveFilePath, fmt.Errorf("failed to reset file position: %w", err))
	}

	if size < DefaultMultipartThreshold {
		return simpleUpload(ctx, orgId, reader, size)
	}
	return multipartUpload(ctx, orgId, reader, size)
}

func simpleUpload(ctx context.Context, orgId string, reader io.ReadSeeker, size int64) (string, error) {
	ghlog.Logger.Info("Uploading file to GitHub",
		zap.String("orgId", fmt.Sprintf("%v", orgId)))

	blobName := filepath.Base(reader.(*os.File).Name())

	// Create a new GitHub client
	githubClient := clients.NewGitHubClient(os.Getenv("GITHUB_PAT"))
	client, err := githubClient.GitHubAuth()
	if err != nil {
		return "", fmt.Errorf("failed to create GitHub client: %v", err)
	}

	// Upload the file
	url := fmt.Sprintf("https://uploads.github.com/organizations/%s/gei/archive?name=%s", orgId, blobName)
	req, err := http.NewRequestWithContext(ctx, "POST", url, reader)
	if err != nil {
		return "", logAndReturnError(blobName, fmt.Errorf("failed to create HTTP request: %w", err))
	}

	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("User-Agent", "gh-glx-migrator")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", os.Getenv("GITHUB_PAT")))
	req.ContentLength = size

	resp, err := client.Client().Do(req)
	if err != nil {
		return "", logAndReturnError(blobName, fmt.Errorf("failed to upload file: %w", err))
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			ghlog.Logger.Error("failed to close response body", zap.Error(err))
		}
	}()

	if resp.StatusCode != http.StatusCreated {
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return "", fmt.Errorf("failed to read response body: %v", err)
		}
		defer func() {
			if err := resp.Body.Close(); err != nil {
				ghlog.Logger.Error("failed to close response body", zap.Error(err))
			}
		}()
		return "", fmt.Errorf("unexpected response status: %d, body: %s", resp.StatusCode, string(body))
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		ghlog.Logger.Error("Failed to read response body", zap.Error(err))
		return "", fmt.Errorf("failed to read response body: %v", err)
	}
	var uploadArchiveResponse UploadArchiveResponse

	// unmarshal the response
	if err := json.Unmarshal(body, &uploadArchiveResponse); err != nil {
		ghlog.Logger.Error("Failed to decode response", zap.Error(err))
		return "", fmt.Errorf("failed to decode response: %v", err)
	}

	return uploadArchiveResponse.URI, nil
}

func multipartUpload(ctx context.Context, orgId string, reader io.ReadSeeker, size int64) (string, error) {
	ghlog.Logger.Info("Uploading file to GitHub",
		zap.String("orgId", fmt.Sprintf("%v", orgId)))

	blobName := filepath.Base(reader.(*os.File).Name())

	// Create a new GitHub client
	githubClient := clients.NewGitHubClient(os.Getenv("GITHUB_TOKEN"))
	client, err := githubClient.GitHubAuth()
	if err != nil {
		return "", fmt.Errorf("failed to create GitHub client: %v", err)
	}

	// Prepare JSON body
	bodyData := map[string]interface{}{
		"content_type": "application/octet-stream",
		"name":         blobName,
		"size":         size,
	}
	jsonBody, _ := json.Marshal(bodyData)

	// Start the upload
	url := fmt.Sprintf("https://uploads.github.com/organizations/%s/gei/archive/blobs/uploads", orgId)
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(jsonBody))
	if err != nil {
		return "", logAndReturnError(blobName, fmt.Errorf("failed to create HTTP request: %w", err))
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "gh-blob")
	req.Header.Set("GraphQL-Features", "octoshift_github_owned_storage")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", os.Getenv("GITHUB_TOKEN")))

	if err != nil {
		return "", logAndReturnError(blobName, fmt.Errorf("failed to marshal JSON body: %w", err))
	}
	resp, err := client.Client().Do(req)
	if err != nil {
		return "", logAndReturnError(blobName, fmt.Errorf("failed to upload file: %w", err))
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			ghlog.Logger.Error("failed to close response body", zap.Error(err))
		}
	}()

	if resp.StatusCode != http.StatusAccepted {
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return "", fmt.Errorf("failed to read response body: %v", err)
		}
		if err := resp.Body.Close(); err != nil {
			ghlog.Logger.Error("failed to close response body", zap.Error(err))
		}
		return "", fmt.Errorf("unexpected response status: %d, body: %s", resp.StatusCode, string(body))
	}

	if _, err := io.ReadAll(resp.Body); err != nil {
		return "", fmt.Errorf("failed to read response body: %v", err)
	}

	// get the Location header from the response
	location := resp.Header.Get("Location")
	if location == "" {
		return "", fmt.Errorf("missing Location header in response")
	}
	// The location looks like this: /organizations/{organization_id}/gei/archive/blobs/uploads?part_number=1&guid=<guid>&upload_id=<upload_id>
	// Parse out the guid and upload_id
	uploadId := ""
	guid := ""
	for _, part := range []string{"guid", "upload_id"} {
		parts := strings.Split(location, part+"=")
		if len(parts) > 1 {
			parts = strings.Split(parts[1], "&")
			if len(parts) > 0 {
				switch part {
				case "guid":
					guid = parts[0]
				case "upload_id":
					uploadId = parts[0]
				}
			}
		}
	}

	ghlog.Logger.Info("Upload ID: " + uploadId)
	ghlog.Logger.Info("GUID: " + guid)

	// Upload file in parts of DefaultPartSize (100 MiB)
	partNumber := 1
	var lastLocation = location
	var nextLocation = location
	var uploadedBytes int64 = 0

	for uploadedBytes < size {
		ghlog.Logger.Info(fmt.Sprintf("Uploading part %d", partNumber))
		// Calculate the size of this part
		partSize := DefaultPartSize
		if size-uploadedBytes < partSize {
			partSize = size - uploadedBytes
		}

		// Read the part into memory
		partBuf := make([]byte, partSize)
		n, err := reader.Read(partBuf)
		if err != nil && err != io.EOF {
			return "", fmt.Errorf("failed to read file part: %v", err)
		}
		if int64(n) != partSize {
			partBuf = partBuf[:n]
		}

		// PATCH request to upload this part
		uploadURL := "https://uploads.github.com" + nextLocation
		req, err := http.NewRequestWithContext(ctx, "PATCH", uploadURL, bytes.NewReader(partBuf))
		if err != nil {
			return "", fmt.Errorf("failed to create PATCH request: %v", err)
		}
		req.Header.Set("Content-Type", "application/octet-stream")
		req.Header.Set("User-Agent", "gh-blob")
		req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", os.Getenv("GITHUB_TOKEN")))
		req.Header.Set("GraphQL-Features", "octoshift_github_owned_storage")
		req.ContentLength = int64(len(partBuf))

		resp, err := client.Client().Do(req)
		if err != nil {
			return "", fmt.Errorf("failed to upload part %d: %v", partNumber, err)
		}
		if resp.StatusCode != http.StatusAccepted {
			body, _ := io.ReadAll(resp.Body)
			if err := resp.Body.Close(); err != nil {
				ghlog.Logger.Error("failed to close response body", zap.Error(err))
			}
			return "", fmt.Errorf("unexpected response status for part %d: %d, body: %s", partNumber, resp.StatusCode, string(body))
		}
		// Save the previous location for the finalization step
		lastLocation = nextLocation
		// Get the next location from the response header
		nextLocation = resp.Header.Get("Location")
		if err := resp.Body.Close(); err != nil {
			ghlog.Logger.Error("failed to close response body", zap.Error(err))
		}

		uploadedBytes += int64(n)
		partNumber++

		// If this is the last part, break the loop
		if uploadedBytes >= size || nextLocation == "" {
			break
		}
	}

	ghlog.Logger.Info("Finalizing upload...")
	// Finalize the upload by sending a POST to the last location
	finalizeURL := "https://uploads.github.com" + lastLocation
	finalizeReq, err := http.NewRequestWithContext(ctx, "PUT", finalizeURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create finalize request: %v", err)
	}
	finalizeReq.Header.Set("Content-Type", "application/octet-stream")
	finalizeReq.Header.Set("User-Agent", "gh-blob")
	finalizeReq.Header.Set("Authorization", fmt.Sprintf("Bearer %s", os.Getenv("GITHUB_TOKEN")))
	finalizeReq.Header.Set("GraphQL-Features", "octoshift_github_owned_storage")

	finalizeResp, err := client.Client().Do(finalizeReq)
	if err != nil {
		return "", fmt.Errorf("failed to finalize upload: %v", err)
	}
	defer func() {
		if err := finalizeResp.Body.Close(); err != nil {
			ghlog.Logger.Error("failed to close finalize response body", zap.Error(err))
		}
	}()

	if finalizeResp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(finalizeResp.Body)
		return "", fmt.Errorf("unexpected finalize response status: %d, body: %s", finalizeResp.StatusCode, string(body))
	}

	body, err := io.ReadAll(finalizeResp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read finalize response body: %v", err)
	}

	var uploadArchiveResponse UploadArchiveResponse

	if err := json.Unmarshal(body, &uploadArchiveResponse); err != nil {
		return "", fmt.Errorf("failed to decode response: %v", err)
	}

	uploadArchiveResponse.URI = fmt.Sprintf("gei://archive/%s", guid)
	uploadArchiveResponse.GUID = guid
	uploadArchiveResponse.NodeID = "Not available"
	uploadArchiveResponse.Name = blobName
	uploadArchiveResponse.Size = int(size)
	uploadArchiveResponse.CreatedAt = finalizeResp.Header.Get("Date")

	return uploadArchiveResponse.URI, nil
}

func logAndReturnError(blobName string, err error) error {
	ghlog.Logger.Error("GitHub upload operation failed",
		zap.String("blobName", blobName),
		zap.Error(err))

	return fmt.Errorf("upload failed: %w", err)
}

func CreateMigrationSource(input MigrationSourceInput) (*MigrationSourceResponse, error) {
	// Ensure URL has proper scheme
	if !strings.HasPrefix(input.URL, "http://") && !strings.HasPrefix(input.URL, "https://") {
		input.URL = "https://" + input.URL
	}

	ghlog.Logger.Info("Creating migration source",
		zap.String("name", input.Name),
		zap.String("url", input.URL),
		zap.String("ownerId", input.OwnerID))

	// Get environment variables
	githubToken := os.Getenv("GITHUB_PAT")
	githubHost := os.Getenv("GITHUB_API_ENDPOINT")

	if githubHost == "" {
		githubHost = "api.github.com"
	}

	// Initialize GitHub client with proper headers
	githubClient := clients.NewGitHubClient(githubToken)
	client, err := githubClient.GitHubAuth()

	if err != nil {
		return nil, fmt.Errorf("failed to create GitHub client: %v", err)
	}

	mutation := `
	mutation createMigrationSource(
			$name: String!
			$url: String!
			$ownerId: ID!
			$type: MigrationSourceType!
	) {
			createMigrationSource(
					input: {
							name: $name
							url: $url
							ownerId: $ownerId
							type: $type
					}
			) {
					migrationSource {
							id
							name
							url
							type
					}
			}
	}`

	requestBody := map[string]interface{}{
		"query": mutation,
		"variables": map[string]interface{}{
			"name":    input.Name,
			"url":     input.URL,
			"ownerId": input.OwnerID,
			"type":    "GL_EXPORTER_ARCHIVE",
		},
		"operationName": "createMigrationSource",
	}

	jsonBody, err := json.Marshal(requestBody)
	if err != nil {
		ghlog.Logger.Error("Failed to marshal request body", zap.Error(err))
		return nil, fmt.Errorf("failed to marshal request body: %v", err)
	}

	url := fmt.Sprintf("https://%s/graphql", githubHost)

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		ghlog.Logger.Error("Failed to create HTTP request", zap.Error(err))
		return nil, fmt.Errorf("failed to create HTTP request: %v", err)
	}

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", githubToken))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "gh-glx-migrator")
	req.Header.Set("GraphQL-Features", "octoshift_gl_exporter")
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	resp, err := client.Client().Do(req)
	if err != nil {
		ghlog.Logger.Error("Failed to make GraphQL request", zap.Error(err))
		return nil, fmt.Errorf("failed to make GraphQL request: %v", err)
	}

	// if the response status is not 200, show error message
	// and the response body and return an error
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected response status: %d, body: %s", resp.StatusCode, func() string {
			body, _ := io.ReadAll(resp.Body)
			return string(body)
		}())
	}

	defer func() {
		if err := resp.Body.Close(); err != nil {
			ghlog.Logger.Error("failed to close response body", zap.Error(err))
		}
	}()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		ghlog.Logger.Error("Failed to read response body", zap.Error(err))
		return nil, fmt.Errorf("failed to read response body: %v", err)
	}

	ghlog.Logger.Debug("Raw response", zap.String("body", string(body)))

	var response struct {
		Data   MigrationSourceResponse `json:"data"`
		Errors []struct {
			Message string   `json:"message"`
			Type    string   `json:"type"`
			Path    []string `json:"path"`
		} `json:"errors,omitempty"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		ghlog.Logger.Error("Failed to decode response", zap.Error(err))
		return nil, fmt.Errorf("failed to decode response: %v", err)
	}

	if len(response.Errors) > 0 {
		errMsg := response.Errors[0].Message
		ghlog.Logger.Error("GraphQL mutation returned an error",
			zap.String("error", errMsg),
			zap.String("type", response.Errors[0].Type),
			zap.Strings("path", response.Errors[0].Path))
		return nil, fmt.Errorf("GraphQL error: %s", errMsg)
	}

	ghlog.Logger.Info("Successfully created migration source",
		zap.String("name", input.Name),
		zap.String("id", response.Data.CreateMigrationSource.MigrationSource.ID))

	return &response.Data, nil
}

func StartMigration(input MigrationInput) (*MigrationResponse, error) {
	ghlog.Logger.Info("Starting repository migration",
		zap.String("repository", input.RepositoryName),
		zap.String("source", input.SourceRepositoryURL))

	// Get environment variables
	githubToken := os.Getenv("GITHUB_PAT")
	githubHost := os.Getenv("GITHUB_API_ENDPOINT")

	if githubHost == "" {
		githubHost = "api.github.com"
	}

	// Initialize GitHub client
	githubClient := clients.NewGitHubClient(githubToken)
	client, err := githubClient.GitHubAuth()

	if err != nil {
		return nil, fmt.Errorf("failed to create GitHub client: %v", err)
	}

	mutation := `
	mutation startRepositoryMigration(
			$sourceId: ID!,
			$ownerId: ID!,
			$sourceRepositoryUrl: URI!,
			$repositoryName: String!,
			$continueOnError: Boolean!,
  		$skipReleases: Boolean,
			$gitArchiveUrl: String!,
			$metadataArchiveUrl: String!,
			$accessToken: String!,
			$githubPat: String,
			$targetRepoVisibility: String,
			$lockSource: Boolean
	) {
			startRepositoryMigration(input: {
					sourceId: $sourceId
					ownerId: $ownerId
					sourceRepositoryUrl: $sourceRepositoryUrl
					repositoryName: $repositoryName
					continueOnError: $continueOnError
					skipReleases: $skipReleases
					gitArchiveUrl: $gitArchiveUrl
					metadataArchiveUrl: $metadataArchiveUrl
					accessToken: $accessToken
					githubPat: $githubPat
					targetRepoVisibility: $targetRepoVisibility
					lockSource: $lockSource
			}) {
					repositoryMigration {
							id
							databaseId
							migrationSource {
									id
									name
									type
							}
							sourceUrl
					}
			}
	}`

	requestBody := map[string]interface{}{
		"query":         mutation,
		"variables":     input,
		"operationName": "startRepositoryMigration",
	}

	jsonBody, err := json.Marshal(requestBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request body: %v", err)
	}

	url := fmt.Sprintf("https://%s/graphql", githubHost)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create HTTP request: %v", err)
	}

	// Set headers
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", githubToken))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "gh-glx-migrator")
	req.Header.Set("GraphQL-Features", "octoshift_gl_exporter")
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	// Make request
	resp, err := client.Client().Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to make GraphQL request: %v", err)
	}

	// if the response status is not 200, show error message
	// and the response body and return an error
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected response status: %d, body: %s", resp.StatusCode, func() string {
			body, _ := io.ReadAll(resp.Body)
			return string(body)
		}())
	}

	defer func() {
		if err := resp.Body.Close(); err != nil {
			ghlog.Logger.Error("failed to close response body", zap.Error(err))
		}
	}()

	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %v", err)
	}

	// Parse response
	var response struct {
		Data   MigrationResponse `json:"data"`
		Errors []struct {
			Message string   `json:"message"`
			Type    string   `json:"type"`
			Path    []string `json:"path"`
		} `json:"errors,omitempty"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return nil, fmt.Errorf("failed to decode response: %v", err)
	}

	// Check for GraphQL errors
	if len(response.Errors) > 0 {
		errMsg := response.Errors[0].Message
		return nil, fmt.Errorf("GraphQL error: %s", errMsg)
	}

	ghlog.Logger.Info("Successfully started repository migration",
		zap.String("repository", input.RepositoryName),
		zap.String("migration_id", response.Data.StartRepositoryMigration.RepositoryMigration.ID))

	return &response.Data, nil
}

func VerifyMigrationStatus(migrationID string, timeout time.Duration) (*MigrationState, error) {
	// Initialize GitHub client

	// Get environment variables
	githubToken := os.Getenv("GITHUB_PAT")
	githubHost := os.Getenv("GITHUB_API_ENDPOINT")
	if githubHost == "" {
		githubHost = "api.github.com"
	}

	githubClient := clients.NewGitHubClient(githubToken)
	client, err := githubClient.GitHubAuth()
	if err != nil {
		return nil, fmt.Errorf("failed to create GitHub client: %v", err)
	}

	// Create progress bar
	bar := pb.New(100)
	bar.SetTemplate(`{{string . "prefix"}} {{bar . }} {{percent . }}`)
	bar.Set("prefix", "Migrating")
	bar.SetWidth(80)
	bar.SetMaxWidth(80)
	bar.Start()
	defer bar.Finish()

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	query := `query($id: ID!) {
			node(id: $id) {
					... on Migration {
							id
							sourceUrl
							databaseId
							migrationSource {
									name
									url
							}
							state
							failureReason
							repositoryName
					}
			}
	}`

	for {
		select {
		case <-ctx.Done():
			bar.Set("prefix", "\033[31mTimeout\033[0m")
			return nil, fmt.Errorf("timeout waiting for migration to complete")
		case <-ticker.C:
			requestBody := map[string]interface{}{
				"query": query,
				"variables": map[string]interface{}{
					"id": migrationID,
				},
			}

			jsonBody, err := json.Marshal(requestBody)
			if err != nil {
				return nil, fmt.Errorf("failed to marshal request body: %v", err)
			}

			url := fmt.Sprintf("https://%s/graphql", githubHost)
			req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
			if err != nil {
				return nil, fmt.Errorf("failed to create request: %v", err)
			}

			req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", githubToken))
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("User-Agent", "gh-glx-migrator")

			resp, err := client.Client().Do(req)
			if err != nil {
				return nil, fmt.Errorf("failed to make request: %v", err)
			}

			var response struct {
				Data   MigrationState `json:"data"`
				Errors []struct {
					Message string `json:"message"`
				} `json:"errors,omitempty"`
			}

			if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
				if err := resp.Body.Close(); err != nil {
					ghlog.Logger.Error("failed to close response body", zap.Error(err))
				}
				return nil, fmt.Errorf("failed to decode response: %v", err)
			}
			if err := resp.Body.Close(); err != nil {
				ghlog.Logger.Error("failed to close response body", zap.Error(err))
			}

			if len(response.Errors) > 0 {
				return nil, fmt.Errorf("GraphQL error: %s", response.Errors[0].Message)
			}

			state := response.Data.Node.State
			switch state {
			case "PENDING":
				bar.Set("prefix", "Validating")
				bar.SetCurrent(25)
			case "QUEUED":
				bar.Set("prefix", "Queued")
				bar.SetCurrent(50)
			case "IN_PROGRESS":
				bar.Set("prefix", "In Progress")
				bar.SetCurrent(75)
			case "SUCCEEDED":
				bar.Set("prefix", "\033[32mCompleted\033[0m")
				bar.SetCurrent(100)
				return &response.Data, nil
			case "FAILED":
				bar.Set("prefix", "\033[31mFailed\033[0m")
				bar.SetCurrent(100)
				return &response.Data, fmt.Errorf("migration failed: %s", response.Data.Node.FailureReason)
			}
		}
	}
}
