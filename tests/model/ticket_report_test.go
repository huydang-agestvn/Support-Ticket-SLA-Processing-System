package domain_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"support-ticket.com/internal/model"
)

func TestTicketReport_Validate(t *testing.T) {
	now := time.Now()

	validReport := func() *model.TicketReport {
		return &model.TicketReport{
			ReportDate:          now,
			NewCount:            10,
			ResolvedCount:       5,
			CancelledCount:      2,
			OverdueCount:        1,
			AvgResolutionTime:   1.5,
			HighPriorityCount:   3,
			MediumPriorityCount: 4,
			LowPriorityCount:    3,
			SlaBreacheCount:     0,
		}
	}

	tests := []struct {
		name        string
		modify      func(*model.TicketReport)
		expectError bool
		errorMsg    string
	}{
		{"Valid", func(r *model.TicketReport) {}, false, ""},
		{"Zero ReportDate", func(r *model.TicketReport) { r.ReportDate = time.Time{} }, true, "Report date is required"},
		{"Negative NewCount", func(r *model.TicketReport) { r.NewCount = -1 }, true, "Status counts cannot be negative"},
		{"Negative ResolvedCount", func(r *model.TicketReport) { r.ResolvedCount = -1 }, true, "Status counts cannot be negative"},
		{"Negative CancelledCount", func(r *model.TicketReport) { r.CancelledCount = -1 }, true, "Status counts cannot be negative"},
		{"Negative OverdueCount", func(r *model.TicketReport) { r.OverdueCount = -1 }, true, "Overdue count cannot be negative"},
		{"Negative SlaBreacheCount", func(r *model.TicketReport) { r.SlaBreacheCount = -1 }, true, "SLA breach count cannot be negative"},
		{"Negative AvgResolutionTime", func(r *model.TicketReport) { r.AvgResolutionTime = -1.5 }, true, "Average resolution time cannot be negative"},
		{"Negative HighPriorityCount", func(r *model.TicketReport) { r.HighPriorityCount = -1 }, true, "Priority counts cannot be negative"},
		{"Negative MediumPriorityCount", func(r *model.TicketReport) { r.MediumPriorityCount = -1 }, true, "Priority counts cannot be negative"},
		{"Negative LowPriorityCount", func(r *model.TicketReport) { r.LowPriorityCount = -1 }, true, "Priority counts cannot be negative"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			report := validReport()
			tt.modify(report)

			err := report.Validate()
			if tt.expectError {
				assert.Error(t, err)
				if tt.errorMsg != "" {
					assert.Contains(t, err.Error(), tt.errorMsg)
				}
			} else {
				assert.NoError(t, err)
			}
		})
	}
}
