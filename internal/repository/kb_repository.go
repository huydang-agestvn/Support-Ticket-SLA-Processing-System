package repository

import (
	"context"

	"github.com/pgvector/pgvector-go"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"support-ticket.com/internal/model"
)

type TicketMatch struct {
	model.SampleTicket
	Similarity float64 `gorm:"column:similarity"`
}

type DepartmentMatch struct {
	model.SubDepartment
	Similarity float64 `gorm:"column:similarity"`
}

type KnowledgeBaseRepository interface {
	SearchSimilarTickets(ctx context.Context, ticketEmbedding []float32, limit int, threshold float64) ([]TicketMatch, error)
	SearchSimilarDepartments(ctx context.Context, ticketEmbedding []float32, limit int, threshold float64) ([]DepartmentMatch, error)
}

type kbRepo struct {
	db *gorm.DB
}

func NewKnowledgeBaseRepository(db *gorm.DB) KnowledgeBaseRepository {
	return &kbRepo{db: db}
}

func (r *kbRepo) SearchSimilarTickets(ctx context.Context, ticketEmbedding []float32, limit int, threshold float64) ([]TicketMatch, error) {
	var results []TicketMatch
	vectorVal := pgvector.NewVector(ticketEmbedding)

	err := r.db.WithContext(ctx).
		Table("sample_tickets").
		Select("*, 1 - (embedding <=> ?) as similarity", vectorVal).
		Where("1 - (embedding <=> ?) >= ?", vectorVal, threshold).
		Clauses(clause.OrderBy{Expression: clause.Expr{SQL: "embedding <=> ?", Vars: []interface{}{vectorVal}}}).
		Limit(limit).
		Scan(&results).Error

	return results, err
}

func (r *kbRepo) SearchSimilarDepartments(ctx context.Context, ticketEmbedding []float32, limit int, threshold float64) ([]DepartmentMatch, error) {
	var results []DepartmentMatch
	vectorVal := pgvector.NewVector(ticketEmbedding)

	err := r.db.WithContext(ctx).
		Table("sub_departments").
		Select("*, 1 - (embedding <=> ?) as similarity", vectorVal).
		Where("is_active = ? AND 1 - (embedding <=> ?) >= ?", true, vectorVal, threshold).
		Clauses(clause.OrderBy{Expression: clause.Expr{SQL: "embedding <=> ?", Vars: []interface{}{vectorVal}}}).
		Limit(limit).
		Scan(&results).Error

	return results, err
}
