package model

// SampleTicket represents the sample_tickets table in DB
type SampleTicket struct {
	ID                uint   `gorm:"primaryKey;autoIncrement" json:"id"`
	SubDepartmentCode string `gorm:"type:varchar(10);not null" json:"sub_department_code"`
	Title             string `gorm:"type:text;not null" json:"title"`
	Description       string `gorm:"type:text;not null" json:"description"`

	TriageCategory              string  `gorm:"type:varchar(50)" json:"triage_category"`
	TriageUrgencyLevel          string  `gorm:"type:varchar(20)" json:"triage_urgency_level"`
	TriageSLABreachRisk         string  `gorm:"type:varchar(20)" json:"triage_sla_breach_risk"`
	TriageReasonSummary         string  `gorm:"type:text" json:"triage_reason_summary"`
	TriageRecommendedNextAction string  `gorm:"type:text" json:"triage_recommended_next_action"`
	TriageConfidenceScore       float64 `gorm:"type:numeric" json:"triage_confidence_score"`

	Embedding      Vector `gorm:"type:vector(384);index:idx_sample_tickets_embedding,class:vector_cosine_ops,type:hnsw" json:"embedding,omitempty"`
	EmbeddingModel string `gorm:"type:varchar(100)" json:"embedding_model,omitempty"`
	IsVerified     bool   `gorm:"not null;default:false" json:"is_verified"`
	AuditModel

	SubDepartment *SubDepartment `gorm:"foreignKey:SubDepartmentCode" json:"sub_department,omitempty"`
}

// TableName overrides the GORM default table name mapping to match the schema
func (SampleTicket) TableName() string {
	return "sample_tickets"
}
