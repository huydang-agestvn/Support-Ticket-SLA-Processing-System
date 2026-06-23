package repository

import (
	"context"

	"gorm.io/gorm"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/model"
)

type TriageRepository interface {
	Create(ctx context.Context, result *model.AITicketTriageResult) error
	FindLatestByTicketID(ctx context.Context, ticketID uint) (*model.AITicketTriageResult, error)
	GetActiveRulePatterns(ctx context.Context) ([]response.RulePatternResponse, error)
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

func (r *triageRepositoryImpl) GetActiveRulePatterns(ctx context.Context) ([]response.RulePatternResponse, error) {
	var patterns []response.RulePatternResponse
	err := r.getDB(ctx).
		Table("rule_patterns").
		Select("rule_patterns.id, rule_patterns.sub_department_code, rule_patterns.pattern, rule_patterns.pattern_type, rule_patterns.priority, rule_patterns.is_active, rule_patterns.created_at, sub_departments.name as name, sub_departments.floor as floor, sub_departments.description as description").
		Joins("left join sub_departments on rule_patterns.sub_department_code = sub_departments.code").
		Where("rule_patterns.is_active = ?", true).
		Find(&patterns).
		Error
	return patterns, err
}
