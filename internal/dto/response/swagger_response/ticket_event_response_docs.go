package swagger_response

type TicketEventImportResultDoc struct {
	AcceptedCount  int `json:"accepted_count" example:"95"`
	RejectedCount  int `json:"rejected_count" example:"3"`
	DuplicateCount int `json:"duplicate_count" example:"2"`
}

type ImportTicketEventsSuccessResponseDoc struct {
	Success bool                     `json:"success" example:"true"`
	Data    TicketEventImportResultDoc `json:"data"`
	Message string                   `json:"message" example:"import completed"`
}