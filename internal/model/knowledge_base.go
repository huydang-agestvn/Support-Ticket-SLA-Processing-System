package model

import (
	"database/sql/driver"
	"fmt"
	"strconv"
	"strings"
	"time"
)

// Vector represents a multidimensional float32 vector in PostgreSQL (pgvector)
type Vector []float32

// Value implements the driver.Valuer interface to convert Vector to string representation for PostgreSQL
func (v Vector) Value() (driver.Value, error) {
	if len(v) == 0 {
		return nil, nil
	}
	var str strings.Builder
	str.WriteByte('[')
	for i, f := range v {
		if i > 0 {
			str.WriteByte(',')
		}
		str.WriteString(strconv.FormatFloat(float64(f), 'f', -1, 32))
	}
	str.WriteByte(']')
	return str.String(), nil
}

// Scan implements the sql.Scanner interface to parse PostgreSQL vector string representation back to Vector
func (v *Vector) Scan(src interface{}) error {
	if src == nil {
		*v = nil
		return nil
	}
	var s string
	switch val := src.(type) {
	case string:
		s = val
	case []byte:
		s = string(val)
	default:
		return fmt.Errorf("unsupported type for Vector scan: %T", src)
	}

	s = strings.Trim(s, "[]")
	if s == "" {
		*v = []float32{}
		return nil
	}
	parts := strings.Split(s, ",")
	res := make([]float32, len(parts))
	for i, p := range parts {
		f, err := strconv.ParseFloat(strings.TrimSpace(p), 32)
		if err != nil {
			return err
		}
		res[i] = float32(f)
	}
	*v = res
	return nil
}

// Department represents the departments table in DB
type Department struct {
	Code      string    `gorm:"primaryKey;type:varchar(10)" json:"code"`
	Name      string    `gorm:"type:varchar(200);not null" json:"name"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updated_at"`

	SubDepartments []SubDepartment `gorm:"foreignKey:DepartmentCode;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"sub_departments,omitempty"`
}

// TableName overrides the GORM default table name mapping to match the schema
func (Department) TableName() string {
	return "departments"
}

// SubDepartment represents the sub_departments table in DB
type SubDepartment struct {
	Code               string     `gorm:"primaryKey;type:varchar(10)" json:"code"`
	DepartmentCode     string     `gorm:"type:varchar(10);not null" json:"department_code"`
	Name               string     `gorm:"type:varchar(200);not null" json:"name"`
	Floor              string     `gorm:"type:varchar(30)" json:"floor"`
	Description        string     `gorm:"type:text;not null" json:"description"`
	Embedding          Vector     `gorm:"type:vector(368) NULL" json:"embedding,omitempty"`
	EmbeddingModel     string     `gorm:"type:varchar(100)" json:"embedding_model,omitempty"`
	EmbeddingUpdatedAt *time.Time `json:"embedding_updated_at,omitempty"`
	IsActive           bool       `gorm:"not null;default:true" json:"is_active"`
	CreatedAt          time.Time  `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt          time.Time  `gorm:"autoUpdateTime" json:"updated_at"`

	Department    *Department    `gorm:"foreignKey:DepartmentCode" json:"department,omitempty"`
	RulePatterns  []RulePattern  `gorm:"foreignKey:SubDepartmentCode;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"rule_patterns,omitempty"`
	SampleTickets []SampleTicket `gorm:"foreignKey:SubDepartmentCode;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"sample_tickets,omitempty"`
}

// TableName overrides the GORM default table name mapping to match the schema
func (SubDepartment) TableName() string {
	return "sub_departments"
}

// RulePattern represents the rule_patterns table in DB
type RulePattern struct {
	ID                uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	SubDepartmentCode string    `gorm:"type:varchar(10);not null" json:"sub_department_code"`
	Pattern           string    `gorm:"type:text;not null" json:"pattern"`
	PatternType       string    `gorm:"type:varchar(20);not null;default:'keyword'" json:"pattern_type"`
	Priority          int       `gorm:"not null" json:"priority"`
	IsActive          bool      `gorm:"not null;default:true" json:"is_active"`
	CreatedAt         time.Time `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt         time.Time `gorm:"autoUpdateTime" json:"updated_at"`

	SubDepartment *SubDepartment `gorm:"foreignKey:SubDepartmentCode" json:"sub_department,omitempty"`
}

// TableName overrides the GORM default table name mapping to match the schema
func (RulePattern) TableName() string {
	return "rule_patterns"
}

// SampleTicket represents the sample_tickets table in DB
type SampleTicket struct {
	ID                 uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	SubDepartmentCode  string     `gorm:"type:varchar(10);not null" json:"sub_department_code"`
	SampleText         string     `gorm:"type:text;not null" json:"sample_text"`
	Embedding          Vector     `gorm:"type:vector(368) NULL" json:"embedding,omitempty"`
	EmbeddingModel     string     `gorm:"type:varchar(100)" json:"embedding_model,omitempty"`
	EmbeddingUpdatedAt *time.Time `json:"embedding_updated_at,omitempty"`
	CreatedAt          time.Time  `gorm:"autoCreateTime" json:"created_at"`

	SubDepartment *SubDepartment `gorm:"foreignKey:SubDepartmentCode" json:"sub_department,omitempty"`
}

// TableName overrides the GORM default table name mapping to match the schema
func (SampleTicket) TableName() string {
	return "sample_tickets"
}

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
