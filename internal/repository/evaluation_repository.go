package repository

import (
	"context"

	"gorm.io/gorm"
	"support-ticket.com/internal/model"
)

type EvaluationRepository interface {
	GetCases(ctx context.Context, caseIDs []uint) ([]model.AIEvaluationCase, error)
	CreateRun(ctx context.Context, run *model.AIEvaluationRun) error
}

type evaluationRepositoryImpl struct {
	db *gorm.DB
}

func NewEvaluationRepository(db *gorm.DB) EvaluationRepository {
	return &evaluationRepositoryImpl{db: db}
}

func (r *evaluationRepositoryImpl) GetCases(ctx context.Context, caseIDs []uint) ([]model.AIEvaluationCase, error) {
	var cases []model.AIEvaluationCase
	query := r.db.WithContext(ctx)
	if len(caseIDs) > 0 {
		query = query.Where("id IN ?", caseIDs)
	}
	if err := query.Order("id ASC").Find(&cases).Error; err != nil {
		return nil, err
	}
	return cases, nil
}

func (r *evaluationRepositoryImpl) CreateRun(ctx context.Context, run *model.AIEvaluationRun) error {
	return r.db.WithContext(ctx).Create(run).Error
}
