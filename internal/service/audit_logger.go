package service

import (
	"crypto/rand"
	"encoding/csv"
	"fmt"
	"os"
	"path/filepath"
	"time"

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
	WriteAuditLog(records []AuditLogRecord) (string, error)
	GetAuditLogPath(filename string) (string, error)
}

type csvFileAuditLogger struct {
	auditLogDir string
}

func NewCSVFileAuditLogger(auditLogDir string) AuditLogger {
	return &csvFileAuditLogger{
		auditLogDir: auditLogDir,
	}
}

func (l *csvFileAuditLogger) WriteAuditLog(records []AuditLogRecord) (string, error) {
	if err := os.MkdirAll(l.auditLogDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create audit log directory: %w", err)
	}

	timestamp := time.Now().Format("20060102_150405")
	randBytes := make([]byte, 4)
	if _, err := rand.Read(randBytes); err != nil {
		return "", fmt.Errorf("failed to generate random bytes for filename: %w", err)
	}
	fileName := fmt.Sprintf("import_audit_%s_%x.csv", timestamp, randBytes)
	filePath := filepath.Join(l.auditLogDir, fileName)

	file, err := os.Create(filePath)
	if err != nil {
		return "", fmt.Errorf("failed to create audit log file: %w", err)
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	header := []string{"ticket_id", "from_status", "to_status", "assignee_id", "created_at", "error_reason"}
	if err := writer.Write(header); err != nil {
		return "", fmt.Errorf("failed to write CSV header: %w", err)
	}

	for _, item := range records {
		row := []string{
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

	return fileName, nil
}

func (l *csvFileAuditLogger) GetAuditLogPath(filename string) (string, error) {
	safeFilename := filepath.Base(filename)
	filePath := filepath.Join(l.auditLogDir, safeFilename)

	info, err := os.Stat(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return "", common.NewNotFound(common.ErrCodeNotFound, "audit log file not found")
		}
		return "", err
	}
	if info.IsDir() {
		return "", common.NewBadRequest(common.ErrCodeInvalidInput, "requested path is a directory")
	}

	return filePath, nil
}
