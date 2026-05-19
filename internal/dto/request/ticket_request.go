package request

import (
	"time"

	domain "support-ticket.com/internal/model"
)

type CreateTicketReq struct {
	RequestorID string          `json:"-" swaggerignore:"true"`
	Title       string          `json:"title"`
	Description string          `json:"description"`
	Priority    domain.Priority `json:"priority"`
	SlaDueAt    *time.Time      `json:"sla_due_at,omitempty"`
}

type UpdateStatusReq struct {
	Status     domain.TicketStatus `json:"status"`
	Note       string              `json:"note,omitempty"`
	AssigneeID string              `json:"-" swaggerignore:"true"`
}

type TicketFilter struct {
	Status     string `form:"status" binding:"omitempty,oneof=new assigned in_progress resolved closed cancelled"`
	Priority   string `form:"priority" binding:"omitempty,oneof=low medium high"`
	AssigneeID string `form:"assignee_id" binding:"omitempty"`
}
