package model

type AIEvaluationCase struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	RunID     uint   `json:"run_id" gorm:"column:run_id;not null;index"`
	TicketID  *uint  `json:"ticket_id" gorm:"column:ticket_id;index"`
	TestTitle string `json:"test_title" gorm:"column:test_title;type:varchar(255);not null"`

	InputSnapshot string `json:"input_snapshot" gorm:"column:input_snapshot;type:json"`

	ExpectedCategory      string `json:"expected_category" gorm:"column:expected_category;type:varchar(255)"`
	ExpectedUrgency       string `json:"expected_urgency" gorm:"column:expected_urgency;type:varchar(50)"`
	ExpectedSLABreachRisk string `json:"expected_sla_breach_risk" gorm:"column:expected_sla_breach_risk;type:varchar(50)"`

	ActualOutput string `json:"actual_output" gorm:"column:actual_output;type:json"`

	IsPassed      bool   `json:"is_passed" gorm:"column:is_passed;not null;default:false"`
	FallbackUsed  bool   `json:"fallback_used" gorm:"column:fallback_used;not null;default:false"`
	LatencyMs     int64  `json:"latency_ms" gorm:"column:latency_ms"`
	FailureReason string `json:"failure_reason" gorm:"column:failure_reason;type:text"` // Ghi chú error từ API hoặc lý do mismatch

	AuditModel
}
