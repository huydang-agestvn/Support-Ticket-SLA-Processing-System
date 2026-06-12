package request

type AIBatchTriageRequest struct {
	TicketIDs []uint `json:"ticket_ids" binding:"required"`
}
