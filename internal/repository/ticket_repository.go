package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/model"
)

type TicketRepository interface {
	Create(ctx context.Context, ticket *model.Ticket) error
	FindById(ctx context.Context, id uint) (*model.Ticket, error)
	FindAll(ctx context.Context, filter request.TicketFilter, offset int, limit int) ([]model.Ticket, int64, error)
	UpdateStatusWithEvent(ctx context.Context, ticket *model.Ticket, event *model.TicketEvent) error
	GetExistingTicketIDs(ctx context.Context, ticketIDs []uint) (map[uint]bool, error)
	GetTicketStatusAndCreatedAt(ctx context.Context, ticketIDs []uint) (map[uint]model.TicketStatus, map[uint]time.Time, map[uint]string, error)
	Transaction(ctx context.Context, fn func(ctx context.Context) error) error
	UpdateStatusesBatch(ctx context.Context, tickets []model.Ticket) error
}

type ticketRepositoryImpl struct {
	db *gorm.DB
}

func NewTicketRepository(db *gorm.DB) TicketRepository {		
	return &ticketRepositoryImpl{db: db}
}

// Package-private helper to handle context transaction propagation
func getDB(ctx context.Context, fallback *gorm.DB) *gorm.DB {
	if tx, ok := ctx.Value("tx").(*gorm.DB); ok {
		return tx.WithContext(ctx)
	}
	return fallback.WithContext(ctx)
}

func (r *ticketRepositoryImpl) getDB(ctx context.Context) *gorm.DB {
	return getDB(ctx, r.db)
}

func (r *ticketRepositoryImpl) Transaction(ctx context.Context, fn func(ctx context.Context) error) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		txCtx := context.WithValue(ctx, "tx", tx)
		return fn(txCtx)
	})
}

func (r *ticketRepositoryImpl) UpdateStatusesBatch(ctx context.Context, tickets []model.Ticket) error {
	if len(tickets) == 0 {
		return nil
	}
	return r.getDB(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "id"}},
		DoUpdates: clause.AssignmentColumns([]string{"status", "assignee_id", "resolved_at", "cancelled_at"}),
	}).CreateInBatches(tickets, 100).Error
}

func (r *ticketRepositoryImpl) Create(ctx context.Context, ticket *model.Ticket) error {
	return r.getDB(ctx).Create(ticket).Error
}

func (r *ticketRepositoryImpl) FindById(ctx context.Context, id uint) (*model.Ticket, error) {
	var ticket model.Ticket

	err := r.getDB(ctx).Preload("Events").First(&ticket, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}

	return &ticket, nil
}

func (r *ticketRepositoryImpl) FindAll(ctx context.Context, filter request.TicketFilter, offset, limit int) ([]model.Ticket, int64, error) {
	var tickets []model.Ticket
	var total int64

	query := r.getDB(ctx).Model(&model.Ticket{})

	if filter.Status != "" {
		query = query.Where("status = ?", filter.Status)
	}

	if filter.Priority != "" {
		query = query.Where("priority = ?", filter.Priority)
	}

	if filter.AssigneeID != "" {
		query = query.Where("assignee_id = ?", filter.AssigneeID)
	}
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	if total == 0 {
		return []model.Ticket{}, 0, nil
	}
	err := query.Preload("Events").
		Order("created_at DESC").
		Offset(offset).
		Limit(limit).
		Find(&tickets).Error

	if err != nil {
		return nil, 0, err
	}

	return tickets, total, nil
}

func (r *ticketRepositoryImpl) UpdateStatusWithEvent(ctx context.Context, ticket *model.Ticket, event *model.TicketEvent) error {
	return r.getDB(ctx).Transaction(func(tx *gorm.DB) error {
		// 1. Update ticket
		if err := tx.Save(ticket).Error; err != nil {
			return fmt.Errorf("update ticket status: %w", err)
		}

		// 2. Insert event
		if err := tx.Create(event).Error; err != nil {
			return fmt.Errorf("insert ticket event: %w", err)
		}

		return nil
	})
}

func (r *ticketRepositoryImpl) GetExistingTicketIDs(ctx context.Context, ticketIDs []uint) (map[uint]bool, error) {
	var existingIDs []uint
	err := r.getDB(ctx).Model(&model.Ticket{}).Where("id IN ?", ticketIDs).Pluck("id", &existingIDs).Error
	if err != nil {
		return nil, err
	}

	result := make(map[uint]bool)
	for _, id := range existingIDs {
		result[id] = true
	}

	return result, nil
}

func (r *ticketRepositoryImpl) GetTicketStatusAndCreatedAt(ctx context.Context, ticketIDs []uint) (map[uint]model.TicketStatus, map[uint]time.Time, map[uint]string, error) {
	if len(ticketIDs) == 0 {
		return make(map[uint]model.TicketStatus), make(map[uint]time.Time), make(map[uint]string), nil
	}

	type ticketMetadataRow struct {
		ID         uint                `gorm:"column:id"`
		Status     model.TicketStatus `gorm:"column:status"`
		CreatedAt  time.Time           `gorm:"column:created_at"`
		AssigneeID string              `gorm:"column:assignee_id"`
	}

	var rows []ticketMetadataRow
	err := r.getDB(ctx).Model(&model.Ticket{}).
		Select("id, status, created_at, assignee_id").
		Where("id IN ?", ticketIDs).
		Find(&rows).Error
	if err != nil {
		return nil, nil, nil, err
	}

	statuses := make(map[uint]model.TicketStatus, len(rows))
	createdAt := make(map[uint]time.Time, len(rows))
	assignees := make(map[uint]string, len(rows))
	for _, row := range rows {
		statuses[row.ID] = row.Status
		createdAt[row.ID] = row.CreatedAt
		assignees[row.ID] = row.AssigneeID
	}

	return statuses, createdAt, assignees, nil
}


