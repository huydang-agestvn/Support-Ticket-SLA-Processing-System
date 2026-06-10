package repository

import (
	"context"

	"gorm.io/gorm"
	"support-ticket.com/internal/model"
)

type TriageRepository interface {
	Create(ctx context.Context, result *model.AITicketTriageResult) error
}

type triageRepositoryImpl struct {
	db *gorm.DB
}

func NewTriageRepository(db *gorm.DB) TriageRepository {
	return &triageRepositoryImpl{db: db}
}

func (r *triageRepositoryImpl) getDB(ctx context.Context) *gorm.DB {
	return getDB(ctx, r.db)
}

func (r *triageRepositoryImpl) Create(ctx context.Context, result *model.AITicketTriageResult) error {
	return r.getDB(ctx).Create(result).Error
}

