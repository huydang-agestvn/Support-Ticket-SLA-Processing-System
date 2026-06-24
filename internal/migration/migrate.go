package migration

import (
	"context"
	_ "embed"
	"fmt"
	"log/slog"

	"gorm.io/gorm"
	"support-ticket.com/internal/model"
)

var kbSchemaAndSeedSQL string

// RunMigrations
func RunMigrations(db *gorm.DB) error {
	slog.InfoContext(context.Background(), "Running database migrations...")

	// 1. Ensure pgvector extension exists
	if err := db.Exec("CREATE EXTENSION IF NOT EXISTS vector").Error; err != nil {
		slog.WarnContext(context.Background(), "Failed to create vector extension", slog.Any("error", err))
	}

	// 2. AutoMigrate all models
	if err := db.AutoMigrate(
		&model.Ticket{},
		&model.TicketEvent{},
		&model.TicketReport{},
		&model.AITicketTriageResult{},
		&model.AIEvaluationRun{},
		&model.AIEvaluationCase{},
		&model.Department{},
		&model.SubDepartment{},
		&model.RulePattern{},
		&model.SampleTicket{},
	); err != nil {
		return fmt.Errorf("failed to run auto migrations: %w", err)
	}

	// 2.5 Create HNSW indexes for vector cosine similarity search
	slog.InfoContext(context.Background(), "Creating HNSW vector indexes...")
	hnswIndexSQLs := []string{
		`CREATE INDEX IF NOT EXISTS idx_sub_departments_embedding ON sub_departments USING hnsw (embedding vector_cosine_ops);`,
		`CREATE INDEX IF NOT EXISTS idx_sample_tickets_embedding ON sample_tickets USING hnsw (embedding vector_cosine_ops);`,
	}
	for _, sql := range hnswIndexSQLs {
		if err := db.Exec(sql).Error; err != nil {
			slog.WarnContext(context.Background(), "Failed to create vector HNSW index", slog.Any("error", err))
		}
	}

	var sampleCount int64
	if err := db.Table("sample_tickets").Count(&sampleCount).Error; err != nil {
		sampleCount = 0
	}

	if sampleCount == 0 {
		slog.InfoContext(context.Background(), "Seeding knowledge base data from kb_schema_and_seed.sql...")
		if err := db.Exec(kbSchemaAndSeedSQL).Error; err != nil {
			return fmt.Errorf("failed to seed knowledge base: %w", err)
		}
		slog.InfoContext(context.Background(), "Knowledge base seeding completed successfully")
	} else {
		viewSQL := `
		CREATE OR REPLACE VIEW unified_knowledge_base AS
		SELECT 
			'policy' AS source_type,
			code AS sub_department_code,
			description AS content_text,
			embedding
		FROM sub_departments
		WHERE is_active = true
		UNION ALL
		SELECT 
			'example' AS source_type,
			sub_department_code,
			title || ' ' || description AS content_text,
			embedding
		FROM sample_tickets;
		`
		if err := db.Exec(viewSQL).Error; err != nil {
			slog.WarnContext(context.Background(), "Failed to recreate unified_knowledge_base view", slog.Any("error", err))
		}
		slog.InfoContext(context.Background(), "Knowledge base already seeded, skipped seeding")
	}

	slog.InfoContext(context.Background(), "Database migrations completed successfully")
	return nil
}
