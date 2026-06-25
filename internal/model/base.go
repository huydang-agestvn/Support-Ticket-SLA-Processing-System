package model

import (
	"time"
)

// TODO: create by user id
type AuditModel struct {
	CreatedAt time.Time `json:"created_at" gorm:"column:created_at;autoCreateTime;default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `json:"updated_at" gorm:"column:updated_at;autoUpdateTime;default:CURRENT_TIMESTAMP"`
	CreatedBy string    `json:"created_by" gorm:"column:created_by;default:'system'"`
	UpdatedBy string    `json:"updated_by" gorm:"column:updated_by;default:'system'"`
}
