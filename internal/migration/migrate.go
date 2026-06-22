package migration

import (
	_ "embed"
	"fmt"

	"gorm.io/gorm"
	"support-ticket.com/internal/model"
)

//go:embed kb_schema_and_seed.sql
var kbSchemaAndSeedSQL string

// RunMigrations 
func RunMigrations(db *gorm.DB) error {
	fmt.Println("Running database migrations...")

	// 1. Ensure pgvector extension exists
	if err := db.Exec("CREATE EXTENSION IF NOT EXISTS vector").Error; err != nil {
		fmt.Printf("Warning: failed to create vector extension: %v\n", err)
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

	// 3. Seed Knowledge Base if departments table is empty
	var deptCount int64
	if err := db.Table("departments").Count(&deptCount).Error; err != nil {
		deptCount = 0
	}

	if deptCount == 0 {
		fmt.Println("Seeding knowledge base data from kb_schema_and_seed.sql...")
		if err := db.Exec(kbSchemaAndSeedSQL).Error; err != nil {
			return fmt.Errorf("failed to seed knowledge base: %w", err)
		}
		fmt.Println("✓ Knowledge base seeding completed successfully")
	} else {
		// Even if already seeded, make sure the VIEW is up-to-date in case it was altered
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
			sample_text AS content_text,
			embedding
		FROM sample_tickets;
		`
		if err := db.Exec(viewSQL).Error; err != nil {
			fmt.Printf("Warning: failed to recreate unified_knowledge_base view: %v\n", err)
		}
		fmt.Println("Knowledge base already seeded, skipped seeding")
	}

	fmt.Println("✓ Database migrations completed successfully")
	return nil
}
