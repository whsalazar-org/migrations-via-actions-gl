package aws

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"go.uber.org/zap"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"

	"github.com/ps-resources/gh-glx-migrator/internal/clients"
	ghlog "github.com/ps-resources/gh-glx-migrator/pkg/logger"
)

const (
	DefaultPartSize           int64 = 100 * 1024 * 1024
	DefaultMultipartThreshold int64 = 100 * 1024 * 1024
)

type AWSError struct {
	Operation string `json:"operation"`
	Bucket    string `json:"bucket"`
	Key       string `json:"key"`
	Error     string `json:"error"`
}

type S3Manager struct {
	client     *s3.Client
	partSize   int64
	threshold  int64
	bucketName string
}

func NewS3Manager(ctx context.Context, awsClient clients.S3Client, bucket string) (*S3Manager, error) {
	if awsClient == nil {
		return nil, fmt.Errorf("AWS client is nil")
	}

	s3Client, err := awsClient.GetS3Client()
	if err != nil {
		return nil, fmt.Errorf("failed to create S3 client: %w", err)
	}

	_, err = s3Client.ListBuckets(ctx, &s3.ListBucketsInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to validate AWS credentials: %w", err)
	}

	return &S3Manager{
		client:     s3Client,
		partSize:   DefaultPartSize,
		threshold:  DefaultMultipartThreshold,
		bucketName: bucket,
	}, nil
}

func (m *S3Manager) SetPartSize(size int64) {
	if size > 0 {
		m.partSize = size
	}
}

func (m *S3Manager) SetMultipartThreshold(size int64) {
	if size > 0 {
		m.threshold = size
	}
}

func (m *S3Manager) GeneratePresignedURL(ctx context.Context, blobName string, duration time.Duration) (string, error) {
	ghlog.Logger.Info("Generating pre-signed S3 URL",
		zap.String("bucket", m.bucketName),
		zap.String("blobName", blobName),
		zap.Duration("duration", duration))

	presignClient := s3.NewPresignClient(m.client)
	req, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(m.bucketName),
		Key:    aws.String(blobName),
	}, s3.WithPresignExpires(duration))

	if err != nil {
		ghlog.Logger.Error("Failed to generate pre-signed URL",
			zap.String("bucket", m.bucketName),
			zap.String("blobName", blobName),
			zap.Error(err))
		return "", fmt.Errorf("failed to generate pre-signed S3 URL: %w", err)
	}

	return req.URL, nil
}

func (m *S3Manager) Upload(ctx context.Context, blobName string, reader io.ReadSeeker) error {
	operation := "Upload"

	// Set blob name if not provided
	if blobName == "" {
		blobName = filepath.Base(reader.(*os.File).Name())
	}

	currentPos, err := reader.Seek(0, io.SeekCurrent)
	if err != nil {
		return logAndReturnError(operation, m.bucketName, blobName, fmt.Errorf("failed to get current position: %w", err))
	}

	size, err := reader.Seek(0, io.SeekEnd)
	if err != nil {
		return logAndReturnError(operation, m.bucketName, blobName, fmt.Errorf("failed to determine file size: %w", err))
	}

	_, err = reader.Seek(currentPos, io.SeekStart)
	if err != nil {
		return logAndReturnError(operation, m.bucketName, blobName, fmt.Errorf("failed to reset file position: %w", err))
	}

	if size < m.threshold {
		return m.simpleUpload(ctx, blobName, reader)
	}
	return m.multipartUpload(ctx, blobName, reader, size)
}

func logAndReturnError(operation, bucket, blobName string, err error) error {
	ghlog.Logger.Error("S3 operation failed",
		zap.String("operation", operation),
		zap.String("bucket", bucket),
		zap.String("blobName", blobName),
		zap.Error(err))

	return fmt.Errorf("%s failed: %w", operation, err)
}

func (m *S3Manager) abortMultipartUpload(ctx context.Context, blobName string, uploadID *string) {
	if uploadID == nil {
		return
	}

	_, err := m.client.AbortMultipartUpload(ctx, &s3.AbortMultipartUploadInput{
		Bucket:   aws.String(m.bucketName),
		Key:      aws.String(blobName),
		UploadId: uploadID,
	})

	if err != nil {
		ghlog.Logger.Error("Failed to abort multipart upload",
			zap.String("bucket", m.bucketName),
			zap.String("blobName", blobName),
			zap.Error(err))
	}
}

func (m *S3Manager) DeleteObject(ctx context.Context, blobName string) error {
	operation := "DeleteObject"

	_, err := m.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(m.bucketName),
		Key:    aws.String(blobName),
	})

	if err != nil {
		return logAndReturnError(operation, m.bucketName, blobName, fmt.Errorf("failed to delete: %w", err))
	}

	ghlog.Logger.Info("File deleted successfully",
		zap.String("bucket", m.bucketName),
		zap.String("blobName", blobName))
	return nil
}

func (m *S3Manager) multipartUpload(ctx context.Context, blobName string, reader io.ReadSeeker, size int64) error {
	operation := "MultipartUpload"
	ghlog.Logger.Info("Starting multipart upload",
		zap.String("bucket", m.bucketName),
		zap.String("blobName", blobName),
		zap.Int64("size", size))

	createResp, err := m.client.CreateMultipartUpload(ctx, &s3.CreateMultipartUploadInput{
		Bucket: aws.String(m.bucketName),
		Key:    aws.String(blobName),
	})
	if err != nil {
		return logAndReturnError(operation, m.bucketName, blobName, fmt.Errorf("failed to create multipart upload: %w", err))
	}

	uploadID := createResp.UploadId
	var completedParts []types.CompletedPart
	partNumber := 1

	for currentPos := int64(0); currentPos < size; currentPos += m.partSize {
		partSize := min(m.partSize, size-currentPos)
		partBuffer := make([]byte, partSize)

		_, err = io.ReadFull(reader, partBuffer)
		if err != nil {
			m.abortMultipartUpload(ctx, blobName, uploadID)
			return logAndReturnError(operation, m.bucketName, blobName,
				fmt.Errorf("failed to read part %d: %w", partNumber, err))
		}

		// Upload part
		uploadResp, err := m.client.UploadPart(ctx, &s3.UploadPartInput{
			Bucket:     aws.String(m.bucketName),
			Key:        aws.String(blobName),
			UploadId:   uploadID,
			PartNumber: aws.Int32(int32(partNumber)),
			Body:       bytes.NewReader(partBuffer),
		})
		if err != nil {
			m.abortMultipartUpload(ctx, blobName, uploadID)
			return logAndReturnError(operation, m.bucketName, blobName,
				fmt.Errorf("failed to upload part %d: %w", partNumber, err))
		}

		completedParts = append(completedParts, types.CompletedPart{
			ETag:       uploadResp.ETag,
			PartNumber: aws.Int32(int32(partNumber)),
		})
		partNumber++
	}

	_, err = m.client.CompleteMultipartUpload(ctx, &s3.CompleteMultipartUploadInput{
		Bucket:   aws.String(m.bucketName),
		Key:      aws.String(blobName),
		UploadId: uploadID,
		MultipartUpload: &types.CompletedMultipartUpload{
			Parts: completedParts,
		},
	})
	if err != nil {
		m.abortMultipartUpload(ctx, blobName, uploadID)
		return logAndReturnError(operation, m.bucketName, blobName,
			fmt.Errorf("failed to complete multipart upload: %w", err))
	}

	ghlog.Logger.Info("Multipart upload completed successfully",
		zap.String("bucket", m.bucketName),
		zap.String("blobName", blobName),
		zap.Int("parts", partNumber-1))
	return nil
}

func (m *S3Manager) simpleUpload(ctx context.Context, blobName string, reader io.Reader) error {
	operation := "SimpleUpload"

	_, err := m.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket: aws.String(m.bucketName),
		Key:    aws.String(blobName),
		Body:   reader,
	})

	if err != nil {
		return logAndReturnError(operation, m.bucketName, blobName, fmt.Errorf("failed to upload: %w", err))
	}

	ghlog.Logger.Info("File uploaded successfully",
		zap.String("bucket", m.bucketName),
		zap.String("blobName", blobName),
		zap.String("method", "simple"))
	return nil
}
