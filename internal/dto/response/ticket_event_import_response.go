package response

import (
	"time"

	"support-ticket.com/internal/model"
)

type TicketEventImportResponse struct {
	TicketID   uint                `json:"ticket_id"`
	FromStatus domain.TicketStatus `json:"from_status"`
	ToStatus   domain.TicketStatus `json:"to_status"`
	AssigneeID string              `json:"assignee_id"`
	Note       *string             `json:"note,omitempty"`
	CreatedAt  time.Time           `json:"created_at"`
}

type TicketImportResponse struct {
	AcceptedCount  int    `json:"accepted_count"`
	RejectedCount  int    `json:"rejected_count"`
	DuplicateCount int    `json:"duplicate_count"`
	AuditLogFile   string `json:"audit_log_file,omitempty"`
}

func NewTicketImportResponse(result domain.BatchImportResult) TicketImportResponse {
	return TicketImportResponse{
		AcceptedCount:  result.AcceptedCount,
		RejectedCount:  result.RejectedCount,
		DuplicateCount: result.DuplicateCount,
		AuditLogFile:   result.AuditLogFile,
	}
}
