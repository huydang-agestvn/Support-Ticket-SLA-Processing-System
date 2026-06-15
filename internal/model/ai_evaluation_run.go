package model

import "encoding/json"

type AIEvaluationRun struct {
	ID            uint   `json:"id" gorm:"primaryKey"`
	Name          string `json:"name" gorm:"column:name;type:varchar(255);not null"`
	ModelUsed     string `json:"model_used" gorm:"column:model_used;type:varchar(100);not null"`
	PromptVersion string `json:"prompt_version" gorm:"column:prompt_version;type:varchar(50);not null"`

	TotalCases   int     `json:"total_cases" gorm:"column:total_cases;not null;default:0"`
	PassedCases  int     `json:"passed_cases" gorm:"column:passed_cases;not null;default:0"`
	FailedCases  int     `json:"failed_cases" gorm:"column:failed_cases;not null;default:0"`
	AccuracyRate float64 `json:"accuracy_rate" gorm:"column:accuracy_rate;type:numeric(5,2)"`
	AvgLatencyMs int64   `json:"avg_latency_ms" gorm:"column:avg_latency_ms"`
	FallbackUsed bool    `json:"fallback_used" gorm:"column:fallback_used;default:false"`

	DetailsRaw json.RawMessage `json:"details" gorm:"column:details_raw;type:jsonb"`
	AuditModel
}
type EvaluationCaseResult struct {
	TestCaseID          int64  `json:"test_case_id"`
	ActualCategory      string `json:"actual_category"`
	ActualUrgency       string `json:"actual_urgency"`
	ActualSLABreachRisk string `json:"actual_sla_breach_risk"`
	IsOverallPassed     bool   `json:"is_overall_passed"`
	RiskExplanation     string `json:"risk_explanation,omitempty"`
	FailureReason       string `json:"failure_reason,omitempty"`
	LatencyMs           int64  `json:"latency_ms"`
}
