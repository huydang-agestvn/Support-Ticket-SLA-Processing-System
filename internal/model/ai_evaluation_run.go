package model

import (
	"time"
)

type AIEvaluationRun struct {
	ID              uint      `json:"id" gorm:"primaryKey"`
	Name            string    `json:"name" gorm:"column:name;type:varchar(255);not null"`
	Description     string    `json:"description" gorm:"column:description;type:text"`
	RunDate         time.Time `json:"run_date" gorm:"column:run_date;not null;autoCreateTime"`
	OverallAccuracy float64   `json:"overall_accuracy" gorm:"column:overall_accuracy;type:numeric(5,4)"`
	ModelUsed       string    `json:"model_used" gorm:"column:model_used;type:varchar(100)"`

	AuditModel

	Cases []AIEvaluationCase `json:"cases" gorm:"foreignKey:RunID;constraint:OnDelete:CASCADE"`
}
