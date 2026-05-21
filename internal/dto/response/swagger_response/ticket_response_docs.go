package swagger_response

type TicketDoc struct {
	ID          uint    `json:"id" example:"1"`
	AssigneeID  string  `json:"assignee_id" example:"9ee00625-0436-4f11-8bb1-b9e4f3f7bf88"`
	RequestorID string  `json:"requestor_id" example:"0a5389df-ba3a-4494-a095-126d05c7c2e7"`
	Title       string  `json:"title" example:"Cannot access internal system"`
	Description string  `json:"description" example:"User cannot access internal support system"`
	Priority    string  `json:"priority" example:"low"`
	Status      string  `json:"status" example:"assigned"`
	CreatedAt   string  `json:"created_at" example:"2026-05-15T15:19:55.169302+07:00"`
	ResolvedAt  *string `json:"resolved_at" example:""`
	SlaDueAt    string  `json:"sla_due_at" example:"2026-05-17T15:19:55.169302+07:00"`
	CancelledAt *string `json:"cancelled_at" example:""`
}

type EventDoc struct {
	EventID    uint    `json:"event_id" example:"1"`
	TicketID   uint    `json:"ticket_id" example:"1"`
	Note       *string `json:"note" example:"Ticket assigned to support agent"`
	FromStatus string  `json:"from_status" example:"new"`
	ToStatus   string  `json:"to_status" example:"assigned"`
	AssigneeID string  `json:"assignee_id" example:"9ee00625-0436-4f11-8bb1-b9e4f3f7bf88"`
	CreatedAt  string  `json:"created_at" example:"2026-05-15T15:34:25.209535+07:00"`
}

type TicketEventDoc struct {
	ID          uint             `json:"id" example:"1"`
	AssigneeID  string           `json:"assignee_id" example:"9ee00625-0436-4f11-8bb1-b9e4f3f7bf88"`
	RequestorID string           `json:"requestor_id" example:"0a5389df-ba3a-4494-a095-126d05c7c2e7"`
	Title       string           `json:"title" example:"Cannot access internal system"`
	Description string           `json:"description" example:"User cannot access internal support system"`
	Priority    string           `json:"priority" example:"low"`
	Status      string           `json:"status" example:"assigned"`
	CreatedAt   string           `json:"created_at" example:"2026-05-15T15:19:55.169302+07:00"`
	ResolvedAt  *string          `json:"resolved_at" example:""`
	SlaDueAt    string           `json:"sla_due_at" example:"2026-05-17T15:19:55.169302+07:00"`
	CancelledAt *string          `json:"cancelled_at" example:""`
	Events      []TicketEventDoc `json:"events"`
}

type ListTicketsDataDoc struct {
	Items      []TicketEventDoc `json:"items"`
	Total      int              `json:"total" example:"10"`
	Page       int              `json:"page" example:"1"`
	Limit      int              `json:"limit" example:"10"`
	TotalPages int              `json:"total_pages" example:"1"`
}

// =======================================================================================================================
// Response docs for ticket handler

type ListTicketsSuccessResponseDoc struct {
	Success bool               `json:"success" example:"true"`
	Data    ListTicketsDataDoc `json:"data"`
	Message string             `json:"message" example:"Get tickets successfully"`
}

type CreateTicketSuccessResponseDoc struct {
	Success bool      `json:"success" example:"true"`
	Data    TicketDoc `json:"data"`
}

type GetTicketDetailSuccessResponseDoc struct {
	Success bool           `json:"success" example:"true"`
	Data    TicketEventDoc `json:"data"`
}

type UpdateTicketStatusSuccessResponseDoc struct {
	Success bool   `json:"success" example:"true"`
	Message string `json:"message" example:"ticket status updated successfully"`
}
