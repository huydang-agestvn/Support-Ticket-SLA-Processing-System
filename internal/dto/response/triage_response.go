package response

import "time"

type TriageResponse struct {
	Category              string  `json:"category"`
	UrgencyLevel          string  `json:"urgency_level"`
	SLABreachRisk         string  `json:"sla_breach_risk"`
	ReasonSummary         string  `json:"reason_summary"`
	RecommendedNextAction string  `json:"recommended_next_action"`
	ConfidenceScore       float64 `json:"confidence_score"`
	FallbackUsed          bool    `json:"fallback_used"`
	PromptVersion         string  `json:"prompt_version,omitempty"`
}

type BatchTriageResponseItem struct {
	TicketID              uint    `json:"ticket_id"`
	Category              string  `json:"category"`
	UrgencyLevel          string  `json:"urgency_level"`
	SLABreachRisk         string  `json:"sla_breach_risk"`
	ReasonSummary         string  `json:"reason_summary"`
	RecommendedNextAction string  `json:"recommended_next_action"`
	ConfidenceScore       float64 `json:"confidence_score"`
	FallbackUsed          bool    `json:"fallback_used"`
	PromptVersion         string  `json:"prompt_version,omitempty"`
}

type BatchTriageResponse struct {
	Processed []BatchTriageResponseItem `json:"processed"`
	Failed    []BatchTriageFailedItem   `json:"failed"`
}

type BatchTriageFailedItem struct {
	TicketID uint   `json:"ticket_id"`
	Reason   string `json:"reason"`
}

type RulePatternResponse struct {
	ID                uint      `json:"id"`
	SubDepartmentCode string    `json:"sub_department_code"`
	Pattern           string    `json:"pattern"`
	PatternType       string    `json:"pattern_type"`
	Priority          string    `json:"priority"`
	IsActive          bool      `json:"is_active"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
	Name              string    `json:"name"`
	Floor             string    `json:"floor"`
	Description       string    `json:"description"`
}
