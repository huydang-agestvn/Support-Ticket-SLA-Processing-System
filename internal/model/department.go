package model

// Department represents the departments table in DB
type Department struct {
	Code      string    `gorm:"primaryKey;type:varchar(10)" json:"code"`
	Name      string    `gorm:"type:varchar(200);not null" json:"name"`
	AuditModel

	SubDepartments []SubDepartment `gorm:"foreignKey:DepartmentCode;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"sub_departments,omitempty"`
}

// TableName overrides the GORM default table name mapping to match the schema
func (Department) TableName() string {
	return "departments"
}
