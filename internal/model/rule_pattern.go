package model

// RulePattern represents the rule_patterns table in DB
type RulePattern struct {
	ID                uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	SubDepartmentCode string    `gorm:"type:varchar(10);not null" json:"sub_department_code"`
	Pattern           string    `gorm:"type:text;not null" json:"pattern"`
	PatternType       string    `gorm:"type:varchar(20);not null;default:'keyword'" json:"pattern_type"`
	Priority          int       `gorm:"not null" json:"priority"`
	IsActive          bool      `gorm:"not null;default:true" json:"is_active"`
	AuditModel

	SubDepartment *SubDepartment `gorm:"foreignKey:SubDepartmentCode" json:"sub_department,omitempty"`
}

// TableName overrides the GORM default table name mapping to match the schema
func (RulePattern) TableName() string {
	return "rule_patterns"
}
