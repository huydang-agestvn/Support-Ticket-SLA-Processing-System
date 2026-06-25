package model


type RulePattern struct {
	ID                uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	SubDepartmentCode string    `gorm:"type:varchar(10);not null" json:"sub_department_code"`
	Pattern           string    `gorm:"type:text;not null" json:"pattern"`
	PatternType       string    `gorm:"type:varchar(20);not null;default:'keyword'" json:"pattern_type"`
	Priority          Priority  `gorm:"type:varchar(20);not null;" json:"priority"`
	IsActive          bool      `gorm:"not null;default:true" json:"is_active"`
	AuditModel

	SubDepartment *SubDepartment `gorm:"foreignKey:SubDepartmentCode" json:"sub_department,omitempty"`
}

func (RulePattern) TableName() string {
	return "rule_patterns"
}

// RoomFloorValidator is registered by package ai to avoid circular dependency
var RoomFloorValidator func(title, description string) error

