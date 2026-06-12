package ai

import (
	"context"

	"support-ticket.com/internal/model"
)

// TriageResult maps to the JSON schema required for Ticket Triage
type TriageResult struct {
	Category              string  `json:"category"`
	UrgencyLevel          string  `json:"urgency_level"`
	SLABreachRisk         string  `json:"sla_breach_risk"`
	ReasonSummary         string  `json:"reason_summary"`
	RecommendedNextAction string  `json:"recommended_next_action"`
	ConfidenceScore       float64 `json:"confidence_score"`
	FallbackUsed          bool    `json:"fallback_used"`
	PromptVersion         string  `json:"prompt_version,omitempty"`
}

type TriagePromptData struct {
	Ticket      model.Ticket
	Events      []model.TicketEvent
	SLAPolicy   string
	DailyReport *model.TicketReport
	TimeLeft    string
}

// TriageAdapter is the interface for the AI provider
type TriageAdapter interface {
	AnalyzeTicket(ctx context.Context, data TriagePromptData) (*TriageResult, error)
}
