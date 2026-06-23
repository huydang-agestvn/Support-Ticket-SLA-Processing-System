package model

// SubDepartment represents the sub_departments table in DB
type SubDepartment struct {
	Code           string `gorm:"primaryKey;type:varchar(10)" json:"code"`
	DepartmentCode string `gorm:"type:varchar(10);not null" json:"department_code"`
	Name           string `gorm:"type:varchar(200);not null" json:"name"`
	Floor          string `gorm:"type:varchar(30)" json:"floor"`
	Description    string `gorm:"type:text;not null" json:"description"`
	Embedding      Vector `gorm:"type:vector(768);index:idx_sub_departments_embedding,class:vector_cosine_ops,type:hnsw" json:"embedding,omitempty"`
	EmbeddingModel string `gorm:"type:varchar(100)" json:"embedding_model,omitempty"`
	IsActive       bool   `gorm:"not null;default:true" json:"is_active"`
	AuditModel

	Department    *Department    `gorm:"foreignKey:DepartmentCode" json:"department,omitempty"`
	RulePatterns  []RulePattern  `gorm:"foreignKey:SubDepartmentCode;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"rule_patterns,omitempty"`
	SampleTickets []SampleTicket `gorm:"foreignKey:SubDepartmentCode;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"sample_tickets,omitempty"`
}

// TableName overrides the GORM default table name mapping to match the schema
func (SubDepartment) TableName() string {
	return "sub_departments"
}
