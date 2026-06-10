package model

type AIEvaluationCase struct {
	ID               uint   `json:"id" gorm:"primaryKey"`
	RunID            uint   `json:"run_id" gorm:"column:run_id;not null;index"`
	TicketID         *uint  `json:"ticket_id" gorm:"column:ticket_id"`
	ExpectedCategory string `json:"expected_category" gorm:"column:expected_category;type:varchar(255)"`
	ExpectedUrgency  string `json:"expected_urgency" gorm:"column:expected_urgency;type:varchar(50)"`
	ExpectedRisk     string `json:"expected_risk" gorm:"column:expected_risk;type:varchar(50)"`
	ActualCategory   string `json:"actual_category" gorm:"column:actual_category;type:varchar(255)"`
	ActualUrgency    string `json:"actual_urgency" gorm:"column:actual_urgency;type:varchar(50)"`
	ActualRisk       string `json:"actual_risk" gorm:"column:actual_risk;type:varchar(50)"`
	IsPass           bool   `json:"is_pass" gorm:"column:is_pass;not null"`
	FailureReason    string `json:"failure_reason" gorm:"column:failure_reason;type:text"`

	AuditModel

	// Relation
	Run    *AIEvaluationRun `json:"-" gorm:"foreignKey:RunID"`
	Ticket *Ticket          `json:"-" gorm:"foreignKey:TicketID;constraint:OnDelete:SET NULL"`
}
