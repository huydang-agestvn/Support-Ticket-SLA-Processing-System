package model

type AITicketTriageResult struct {
	ID                    uint    `json:"id" gorm:"primaryKey"`
	TicketID              uint    `json:"ticket_id" gorm:"column:ticket_id;not null;index"`
	Category              string  `json:"category" gorm:"column:category;type:varchar(255);not null"`
	UrgencyLevel          string  `json:"urgency_level" gorm:"column:urgency_level;type:varchar(50);not null"`
	SLABreachRisk         string  `json:"sla_breach_risk" gorm:"column:sla_breach_risk;type:varchar(50);not null"`
	ReasonSummary         string  `json:"reason_summary" gorm:"column:reason_summary;type:text;not null"`
	RecommendedNextAction string  `json:"recommended_next_action" gorm:"column:recommended_next_action;type:text;not null"`
	ConfidenceScore       float64 `json:"confidence_score" gorm:"column:confidence_score;type:numeric(5,4);not null"`
	FallbackUsed          bool    `json:"fallback_used" gorm:"column:fallback_used;not null;default:false"`
	PromptVersion         string  `json:"prompt_version" gorm:"column:prompt_version;type:varchar(50);default:'v1'"`

	AuditModel 

	// Relation
	Ticket *Ticket `json:"-" gorm:"foreignKey:TicketID;constraint:OnDelete:CASCADE"`
}
