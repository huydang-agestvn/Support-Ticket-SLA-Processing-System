package model

import (
	"time"
)

type AuditModel struct {
	CreatedAt time.Time `json:"created_at" gorm:"column:created_at;not null;autoCreateTime"`
	UpdatedAt time.Time `json:"updated_at" gorm:"column:updated_at;not null;autoUpdateTime"`
	CreatedBy string `json:"created_by" gorm:"column:created_by"`
	UpdatedBy string `json:"updated_by" gorm:"column:updated_by"`
}
