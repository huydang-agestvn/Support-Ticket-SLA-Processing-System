package repository

import (
	"context"

	"gorm.io/gorm"
	"support-ticket.com/internal/model"
)

type TriageRepository interface {
	Create(ctx context.Context, result *model.AITicketTriageResult) error
	FindLatestByTicketID(ctx context.Context, ticketID uint) (*model.AITicketTriageResult, error)
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

func (r *triageRepositoryImpl) FindLatestByTicketID(ctx context.Context, ticketID uint) (*model.AITicketTriageResult, error) {
	var result model.AITicketTriageResult
	err := r.getDB(ctx).
		Where("ticket_id = ?", ticketID).
		Order("created_at DESC").
		First(&result).
		Error
	if err == gorm.ErrRecordNotFound {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &result, nil
}
