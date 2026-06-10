package repository

import (
	"context"

	"gorm.io/gorm"
	"support-ticket.com/internal/model"
)

type TicketEventRepository interface {
	CreateBatch(ctx context.Context, events []model.TicketEvent) error
	Create(ctx context.Context, event *model.TicketEvent) error
	GetExistingEventKeys(ctx context.Context, keys []string) (map[string]bool, error)
	FetchLatestEventPerTicket(ctx context.Context, ticketIDs []int) ([]model.TicketEvent, error)
	FetchLatestResolvedEventPerTicket(ctx context.Context, ticketIDs []int) ([]model.TicketEvent, error)
}

type ticketEventRepository struct {
	db *gorm.DB
}

func NewTicketEventRepository(db *gorm.DB) TicketEventRepository {
	return &ticketEventRepository{db}
}

func (r *ticketEventRepository) getDB(ctx context.Context) *gorm.DB {
	return getDB(ctx, r.db)
}

// FetchLatestEventPerTicket implements [TicketEventRepository].
func (r *ticketEventRepository) FetchLatestEventPerTicket(ctx context.Context, ticketIDs []int) ([]model.TicketEvent, error) {
	if len(ticketIDs) == 0 {
		return nil, nil
	}

	var results []model.TicketEvent
	err := r.getDB(ctx).
		Model(&model.TicketEvent{}).
		Select("DISTINCT ON (ticket_id) ticket_id, to_status, assignee_id, created_at").
		Where("ticket_id IN ?", ticketIDs).
		Order("ticket_id, created_at DESC").
		Find(&results).Error
	if err != nil {
		return nil, err
	}

	return results, nil
}

func (r *ticketEventRepository) FetchLatestResolvedEventPerTicket(ctx context.Context, ticketIDs []int) ([]model.TicketEvent, error) {
	if len(ticketIDs) == 0 {
		return nil, nil
	}

	var results []model.TicketEvent
	err := r.getDB(ctx).
		Model(&model.TicketEvent{}).
		Select("DISTINCT ON (ticket_id) ticket_id, created_at").
		Where("ticket_id IN ? AND to_status = ?", ticketIDs, model.StatusResolved).
		Order("ticket_id, created_at DESC").
		Find(&results).Error
	if err != nil {
		return nil, err
	}

	return results, nil
}

func (r *ticketEventRepository) CreateBatch(ctx context.Context, events []model.TicketEvent) error {
	return r.getDB(ctx).CreateInBatches(events, 100).Error
}

func (r *ticketEventRepository) Create(ctx context.Context, event *model.TicketEvent) error {
	return r.getDB(ctx).Create(event).Error
}

func (r *ticketEventRepository) GetExistingEventKeys(ctx context.Context, keys []string) (map[string]bool, error) {
	var existingKeys []string
	err := r.getDB(ctx).Raw("SELECT CONCAT(ticket_id, '|', from_status, '|', to_status) as key FROM ticket_events WHERE CONCAT(ticket_id, '|', from_status, '|', to_status) IN (?)", keys).Scan(&existingKeys).Error
	if err != nil {
		return nil, err
	}

	result := make(map[string]bool)
	for _, key := range existingKeys {
		result[key] = true
	}

	return result, nil
}
