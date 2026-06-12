package migration

import (
	"fmt"

	"gorm.io/gorm"
	"support-ticket.com/internal/model"
)

// RunMigrations 
func RunMigrations(db *gorm.DB) error {
	fmt.Println("Running database migrations...")

	if err := db.AutoMigrate(
		&model.Ticket{},
		&model.TicketEvent{},
		&model.TicketReport{},
		&model.AITicketTriageResult{},
		&model.AIEvaluationRun{},
		&model.AIEvaluationCase{},
	); err != nil {
		return fmt.Errorf("failed to run auto migrations: %w", err)
	}

	fmt.Println("✓ Database migrations completed successfully")
	return nil
}
