package request

type EventSummary struct {
    FromStatus string
    ToStatus   string
    AssigneeID string
    Note       string
    CreatedAt  string
}

type TriageRequest struct {
    TicketID       uint
    Title          string
    Description    string
    RequesterID    string
    Priority       string
    CreatedAt      string
    SLADueAt       string
    EventHistory   []EventSummary
    SLABreachCount int64
}