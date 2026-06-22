package model

// UnifiedKnowledgeBase represents the unified_knowledge_base VIEW in DB
type UnifiedKnowledgeBase struct {
	SourceType        string `gorm:"column:source_type" json:"source_type"`
	SubDepartmentCode string `gorm:"column:sub_department_code" json:"sub_department_code"`
	ContentText       string `gorm:"column:content_text" json:"content_text"`
	Embedding         Vector `gorm:"column:embedding" json:"embedding"`
}

// TableName overrides the GORM default table name mapping to match the schema
func (UnifiedKnowledgeBase) TableName() string {
	return "unified_knowledge_base"
}
