package model

type AIEvaluationRun struct {
	ID            uint    `json:"id" gorm:"primaryKey"`
	Name          string  `json:"name" gorm:"column:name;type:varchar(255);not null"`
	ModelUsed     string  `json:"model_used" gorm:"column:model_used;type:varchar(100);not null"`
	PromptVersion string  `json:"prompt_version" gorm:"column:prompt_version;type:varchar(50);not null"`

	TotalCases   int     `json:"total_cases" gorm:"column:total_cases;not null;default:0"`
	PassedCases  int     `json:"passed_cases" gorm:"column:passed_cases;not null;default:0"`
	FailedCases  int     `json:"failed_cases" gorm:"column:failed_cases;not null;default:0"`
	AccuracyRate float64 `json:"accuracy_rate" gorm:"column:accuracy_rate;type:numeric(5,4)"`
	AvgLatencyMs int64   `json:"avg_latency_ms" gorm:"column:avg_latency_ms"`
	FallbackUsed bool    `json:"fallback_used" gorm:"column:fallback_used;default:false"`

	AuditModel


}
