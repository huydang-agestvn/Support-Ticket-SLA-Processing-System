package service

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"support-ticket.com/internal/dto/common"
)

type AuditLogRecord struct {
	TicketID   uint
	FromStatus string
	ToStatus   string
	AssigneeID string
	CreatedAt  time.Time
	Reason     string
}

type AuditLogger interface {
	WriteAuditLog(records []AuditLogRecord, userID string) (string, error)
	GetAuditLogPath(filename string) (string, error)
}

type minioAuditLogger struct {
	client     *minio.Client
	bucketName string
}

func NewMinIOAuditLogger(endpoint, accessKey, secretKey string, useSSL bool, bucketName string) (AuditLogger, error) {
	minioClient, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to initialize minio client: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	exists, err := minioClient.BucketExists(ctx, bucketName)
	if err != nil {
		return nil, fmt.Errorf("failed to check if bucket exists: %w", err)
	}
	if !exists {
		err = minioClient.MakeBucket(ctx, bucketName, minio.MakeBucketOptions{})
		if err != nil {
			return nil, fmt.Errorf("failed to create bucket: %w", err)
		}
	}

	return &minioAuditLogger{
		client:     minioClient,
		bucketName: bucketName,
	}, nil
}

func (l *minioAuditLogger) WriteAuditLog(records []AuditLogRecord, userID string) (string, error) {
	timestamp := time.Now().Format("20060102_150405")
	randBytes := make([]byte, 4)
	if _, err := rand.Read(randBytes); err != nil {
		return "", fmt.Errorf("failed to generate random bytes for filename: %w", err)
	}
	fileName := fmt.Sprintf("import_audit_%s_%x.csv", timestamp, randBytes)

	var buf bytes.Buffer
	writer := csv.NewWriter(&buf)

	header := []string{"user_id", "ticket_id", "from_status", "to_status", "assignee_id", "created_at", "error_reason"}
	if err := writer.Write(header); err != nil {
		return "", fmt.Errorf("failed to write CSV header: %w", err)
	}

	for _, item := range records {
		row := []string{
			userID,
			fmt.Sprintf("%d", item.TicketID),
			item.FromStatus,
			item.ToStatus,
			item.AssigneeID,
			item.CreatedAt.Format(time.RFC3339),
			item.Reason,
		}
		if err := writer.Write(row); err != nil {
			return "", fmt.Errorf("failed to write CSV row: %w", err)
		}
	}
	writer.Flush()
	if err := writer.Error(); err != nil {
		return "", fmt.Errorf("failed to flush CSV writer: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	_, err := l.client.PutObject(ctx, l.bucketName, fileName, &buf, int64(buf.Len()), minio.PutObjectOptions{
		ContentType: "text/csv",
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload audit log to MinIO: %w", err)
	}

	return fileName, nil
}

func (l *minioAuditLogger) GetAuditLogPath(filename string) (string, error) {
	safeFilename := filepath.Base(filename)

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	object, err := l.client.GetObject(ctx, l.bucketName, safeFilename, minio.GetObjectOptions{})
	if err != nil {
		return "", fmt.Errorf("failed to get object from MinIO: %w", err)
	}
	defer object.Close()

	_, err = object.Stat()
	if err != nil {
		if minio.ToErrorResponse(err).Code == "NoSuchKey" {
			return "", common.NewNotFound(common.ErrCodeNotFound, "audit log file not found in MinIO")
		}
		return "", fmt.Errorf("failed to stat object in MinIO: %w", err)
	}

	tempFile, err := os.CreateTemp("", "audit_log_*.csv")
	if err != nil {
		return "", fmt.Errorf("failed to create temp file: %w", err)
	}
	defer tempFile.Close()

	if _, err := io.Copy(tempFile, object); err != nil {
		os.Remove(tempFile.Name())
		return "", fmt.Errorf("failed to write object to temp file: %w", err)
	}

	return tempFile.Name(), nil
}
