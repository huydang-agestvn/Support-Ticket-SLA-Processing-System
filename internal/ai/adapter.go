package ai

import "context"

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

type TriageResponse struct {
	Category              string  `json:"category"`
	UrgencyLevel          string  `json:"urgency_level"`
	SLABreachRisk         string  `json:"sla_breach_risk"`
	ReasonSummary         string  `json:"reason_summary"`
	RecommendedNextAction string  `json:"recommended_next_action"`
	ConfidenceScore       float64 `json:"confidence_score"`
	FallbackUsed          bool    `json:"fallback_used"`
	PromptVersion         string  `json:"prompt_version"`
}

type AIAdapter interface {
	Triage(ctx context.Context, req TriageRequest) (*TriageResponse, error)
}