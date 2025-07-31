package azure

import (
	"context"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/to"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/blob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/sas"
	"go.uber.org/zap"

	"github.com/ps-resources/gh-glx-migrator/pkg/logger"
)

// AzureOptions contains configuration for Azure Blob Storage operations
type AzureOptions struct {
	StorageAccount   string
	StorageAccessKey string
	ContainerName    string
	BlobName         string
	ArchiveFilePath  string
}

// Singleton credential with lazy initialization
var (
	credentialCache    map[string]azblob.SharedKeyCredential
	credentialCacheMux sync.RWMutex
)

func init() {
	credentialCache = make(map[string]azblob.SharedKeyCredential)
}

func getCredential(account, key string) (*azblob.SharedKeyCredential, error) {
	cacheKey := account + ":" + key

	// Lock and check cache in one step to avoid race conditions
	credentialCacheMux.RLock()
	if cred, exists := credentialCache[cacheKey]; exists {
		credentialCacheMux.RUnlock()
		return &cred, nil
	}
	credentialCacheMux.RUnlock()

	// Create new credential
	credential, err := azblob.NewSharedKeyCredential(account, key)
	if err != nil {
		return nil, fmt.Errorf("failed to create credential: %v", err)
	}

	// Store credential in cache with write lock
	credentialCacheMux.Lock()
	credentialCache[cacheKey] = *credential
	credentialCacheMux.Unlock()

	return credential, nil
}

// calculateOptimalBlockSize calculates the optimal block size based on file size
func calculateOptimalBlockSize(fileSize int64) (int64, int) {
	const (
		minBlockSize = 1 * 1024 * 1024   // 1MB
		maxBlockSize = 100 * 1024 * 1024 // 100MB
		targetBlocks = 50                // Target ~50 blocks for optimal performance
	)

	if fileSize < 10*minBlockSize {
		return minBlockSize, 4 // Use fewer goroutines for small files
	}

	blockSize := fileSize / targetBlocks

	if blockSize < minBlockSize {
		blockSize = minBlockSize
	} else if blockSize > maxBlockSize {
		blockSize = maxBlockSize
	}

	blockSize = (blockSize / (1024 * 1024)) * (1024 * 1024)
	parallelism := int(math.Max(1, math.Min(32, math.Sqrt(float64(fileSize/(1024*1024))))))

	return blockSize, parallelism
}

// UploadToAzureBlob uploads a file to Azure Blob Storage and returns a presigned URL
func UploadToAzureBlob(opts *AzureOptions, duration time.Duration) (string, error) {
	logger.Logger.Info("Starting upload to Azure Blob Storage",
		zap.String("container", opts.ContainerName),
		zap.String("blob", opts.BlobName))

	// Validate options
	if opts.StorageAccount == "" || opts.StorageAccessKey == "" || opts.ContainerName == "" {
		return "", fmt.Errorf("storage account, access key, and container name are required")
	}

	// Set blob name if not provided
	if opts.BlobName == "" {
		opts.BlobName = filepath.Base(opts.ArchiveFilePath)
	}

	// Check if file exists and get size
	fileInfo, err := os.Stat(opts.ArchiveFilePath)
	if err != nil {
		if os.IsNotExist(err) {
			return "", fmt.Errorf("file does not exist: %s", opts.ArchiveFilePath)
		}
		return "", fmt.Errorf("failed to stat file: %v", err)
	}
	fileSize := fileInfo.Size()

	// Open file
	file, err := os.Open(opts.ArchiveFilePath)
	if err != nil {
		return "", fmt.Errorf("failed to open file: %v", err)
	}
	defer func() {
		if err := file.Close(); err != nil {
			logger.Logger.Error("failed to close file", zap.Error(err))
		}
	}()

	blockSize, parallelism := calculateOptimalBlockSize(fileSize)

	logger.Logger.Info("Uploading file to Azure",
		zap.String("file", opts.ArchiveFilePath),
		zap.Int64("size", fileSize),
		zap.Int64("block_size", blockSize),
		zap.Int("parallelism", parallelism))

	var account = fmt.Sprintf("https://%s.blob.core.windows.net/", opts.StorageAccount)
	var containerName = opts.ContainerName
	var blobName = opts.BlobName

	// authenticate with Azure Active Directory
	cred, err := getCredential(opts.StorageAccount, opts.StorageAccessKey)
	if err != nil {
		return "", fmt.Errorf("failed to create shared key credential: %v", err)
	}

	// create a client for the specified storage account
	client, err := azblob.NewClientWithSharedKeyCredential(account, cred, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create blob client: %v", err)
	}

	// upload the file to the specified container with the specified blob name
	_, err = client.UploadFile(context.TODO(), containerName, blobName, file,
		&azblob.UploadFileOptions{
			BlockSize:   blockSize,           // 8 MiB
			Concurrency: uint16(parallelism), // Higher concurrency for large files
		})
	if err != nil {
		return "", fmt.Errorf("failed to upload file: %v", err)
	}

	logger.Logger.Info("Upload completed successfully")

	// Generate presigned URL with appropriate duration
	presignedURL, err := GenerateSasUrl(opts, duration)
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned URL: %v", err)
	}

	return presignedURL, nil
}

// GeneratePresignedURL creates a presigned URL for the specified blob
func GenerateSasUrl(opts *AzureOptions, duration time.Duration) (string, error) {
	// Get credential
	credential, err := getCredential(opts.StorageAccount, opts.StorageAccessKey)
	if err != nil {
		return "", err
	}

	sasQueryParams, err := sas.BlobSignatureValues{
		Protocol:      sas.ProtocolHTTPS,
		StartTime:     time.Now().UTC(),
		ExpiryTime:    time.Now().UTC().Add(duration),
		ContainerName: opts.ContainerName,
		BlobName:      opts.BlobName,
		Permissions:   to.Ptr(sas.BlobPermissions{Read: true}).String(),
	}.SignWithSharedKey(credential)
	if err != nil {
		return "", fmt.Errorf("failed to generate SAS query parameters: %v", err)
	}

	// Build the SAS URL
	sasURL := fmt.Sprintf("https://%s.blob.core.windows.net/%s/%s?%s", opts.StorageAccount, opts.ContainerName, opts.BlobName, sasQueryParams.Encode())

	return sasURL, nil
}

func DeleteBlob(opts *AzureOptions) error {
	logger.Logger.Info("Deleting blob from Azure Blob Storage",
		zap.String("container", opts.ContainerName),
		zap.String("blob", opts.BlobName))

	var account = fmt.Sprintf("https://%s.blob.core.windows.net/", opts.StorageAccount)

	credential, err := getCredential(opts.StorageAccount, opts.StorageAccessKey)
	if err != nil {
		return fmt.Errorf("failed to create shared key credential: %v", err)
	}

	client, err := azblob.NewClientWithSharedKeyCredential(account, credential, nil)
	if err != nil {
		return fmt.Errorf("failed to create blob client: %v", err)
	}

	_, err = client.DeleteBlob(context.TODO(), opts.ContainerName, opts.BlobName, &blob.DeleteOptions{
		DeleteSnapshots: to.Ptr(blob.DeleteSnapshotsOptionTypeInclude),
	})
	if err != nil {
		return fmt.Errorf("failed to delete blob: %v", err)
	}

	// log response
	logger.Logger.Info("Blob deleted successfully",
		zap.String("container", opts.ContainerName),
		zap.String("blob", opts.BlobName))

	return nil
}
