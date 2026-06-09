package response

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