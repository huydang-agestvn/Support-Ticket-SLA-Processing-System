package model

type AIEvaluationCase struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	TestTitle string `json:"test_title" gorm:"column:test_title;type:varchar(255);not null"`

	InputSnapshot string `json:"input_snapshot" gorm:"column:input_snapshot;type:json"`

	ExpectedCategory      string `json:"expected_category" gorm:"column:expected_category;type:varchar(255)"`
	ExpectedUrgency       string `json:"expected_urgency" gorm:"column:expected_urgency;type:varchar(50)"`
	ExpectedSLABreachRisk string `json:"expected_sla_breach_risk" gorm:"column:expected_sla_breach_risk;type:varchar(50)"`

	AuditModel
}
