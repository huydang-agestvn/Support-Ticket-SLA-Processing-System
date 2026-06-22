package model

import (
	"time"
)

// SampleTicket represents the sample_tickets table in DB
type SampleTicket struct {
	ID                 uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	SubDepartmentCode  string     `gorm:"type:varchar(10);not null" json:"sub_department_code"`
	SampleText         string     `gorm:"type:text;not null" json:"sample_text"`
	Embedding          Vector     `gorm:"type:vector(368) NULL" json:"embedding,omitempty"`
	EmbeddingModel     string     `gorm:"type:varchar(100)" json:"embedding_model,omitempty"`
	EmbeddingUpdatedAt *time.Time `json:"embedding_updated_at,omitempty"`
	AuditModel

	SubDepartment *SubDepartment `gorm:"foreignKey:SubDepartmentCode" json:"sub_department,omitempty"`
}

// TableName overrides the GORM default table name mapping to match the schema
func (SampleTicket) TableName() string {
	return "sample_tickets"
}
