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
	Distance float64 `gorm:"column:distance"`
}

type DepartmentMatch struct {
	model.SubDepartment
	Distance float64 `gorm:"column:distance"`
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
		Select("*, (embedding <=> ?) as distance", vectorVal).
		Where("embedding <=> ? < ?", vectorVal, threshold).
		Order(clause.Expr{SQL: "embedding <=> ?", Vars: []interface{}{vectorVal}}).
		Limit(limit).
		Scan(&results).Error

	return results, err
}

func (r *kbRepo) SearchSimilarDepartments(ctx context.Context, ticketEmbedding []float32, limit int, threshold float64) ([]DepartmentMatch, error) {
	var results []DepartmentMatch
	vectorVal := pgvector.NewVector(ticketEmbedding)

	err := r.db.WithContext(ctx).
		Table("sub_departments").
		Select("*, (embedding <=> ?) as distance", vectorVal).
		Where("is_active = ? AND embedding <=> ? < ?", true, vectorVal, threshold).
		Order(clause.Expr{SQL: "embedding <=> ?", Vars: []interface{}{vectorVal}}).
		Limit(limit).
		Scan(&results).Error

	return results, err
}
