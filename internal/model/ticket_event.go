package model

import (
	"fmt"
	"time"

	"support-ticket.com/internal/dto/common"
)

type TicketEvent struct {
	ID         uint         `json:"event_id,omitempty" gorm:"primaryKey"`
	TicketID   uint         `json:"ticket_id" gorm:"column:ticket_id;not null"`
	Note       *string      `json:"note" gorm:"column:note;type:text"`
	FromStatus TicketStatus `json:"from_status" gorm:"column:from_status;type:varchar(20);not null"`
	ToStatus   TicketStatus `json:"to_status" gorm:"column:to_status;type:varchar(20);not null"`
	AssigneeID string       `json:"assignee_id" gorm:"column:assignee_id;type:varchar(255);not null"`
	CreatedAt  time.Time    `json:"created_at" gorm:"column:created_at;not null;autoCreateTime:milli"`

	// Relations
	Ticket *Ticket `json:"-" gorm:"foreignKey:TicketID;constraint:OnDelete:CASCADE"`
}

type BatchImportResult struct {
	AcceptedCount  int    `json:"accepted_count"`
	RejectedCount  int    `json:"rejected_count"`
	DuplicateCount int    `json:"duplicate_count"`
	AuditLogFile   string `json:"audit_log_file,omitempty"`
}

func (e *TicketEvent) Validate() error {
	if e.TicketID == 0 {
		return common.NewBadRequest(common.ErrCodeInvalidInput, "ticket_id is required")
	}
	if !e.FromStatus.IsValid() {
		return common.NewBadRequest(common.ErrCodeInvalidInput, fmt.Sprintf("unknown from_status '%s'", e.FromStatus))
	}
	if !e.ToStatus.IsValid() {
		return common.NewBadRequest(common.ErrCodeInvalidInput, fmt.Sprintf("unknown to_status '%s'", e.ToStatus))
	}
	if e.FromStatus == e.ToStatus {
		return common.NewBadRequest(common.ErrCodeInvalidTransition,
			fmt.Sprintf("from_status and to_status cannot be the same ('%s')", e.FromStatus))
	}
	if !e.FromStatus.CanTransitionTo(e.ToStatus) {
		return common.NewBadRequest(common.ErrCodeInvalidTransition,
			fmt.Sprintf("illegal event transition from '%s' to '%s'", e.FromStatus, e.ToStatus))
	}
	if e.CreatedAt.IsZero() {
		return common.NewBadRequest(common.ErrCodeInvalidInput, "event created_at is required")
	}
	return nil
}

func (e *TicketEvent) HashKey() string {
	return fmt.Sprintf("%d|%s|%s", e.TicketID, e.FromStatus, e.ToStatus)
}
