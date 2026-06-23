package repository

import (
	"context"

	"github.com/pgvector/pgvector-go"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"support-ticket.com/internal/model"
)

type KnowledgeBaseRepository interface {
	SearchSimilarContext(ctx context.Context, ticketEmbedding []float32, limit int) ([]model.UnifiedKnowledgeBase, error)
}

type kbRepo struct {
	db *gorm.DB
}

func NewKnowledgeBaseRepository(db *gorm.DB) KnowledgeBaseRepository {
	return &kbRepo{db: db}
}

func (r *kbRepo) SearchSimilarContext(ctx context.Context, ticketEmbedding []float32, limit int) ([]model.UnifiedKnowledgeBase, error) {
	var results []model.UnifiedKnowledgeBase

	// Use pgvector <=> operator to calculate Cosine Distance
	// We order by distance ascending, so lower distance (higher similarity) comes first
	err := r.db.WithContext(ctx).
		Order(clause.Expr{SQL: "embedding <=> ?", Vars: []interface{}{pgvector.NewVector(ticketEmbedding)}}).
		Limit(limit).
		Find(&results).Error

	return results, err
}
