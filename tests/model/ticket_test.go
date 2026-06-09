package domain_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"support-ticket.com/internal/model"
)

func TestPriority_IsValid(t *testing.T) {
	tests := []struct {
		name     string
		priority model.Priority
		expected bool
	}{
		{"Low", model.PriorityLow, true},
		{"Medium", model.PriorityMedium, true},
		{"High", model.PriorityHigh, true},
		{"Invalid", model.Priority("critical"), false},
		{"Empty", model.Priority(""), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.expected, tt.priority.IsValid())
		})
	}
}

func TestTicketStatus_IsValid(t *testing.T) {
	tests := []struct {
		name     string
		status   model.TicketStatus
		expected bool
	}{
		{"New", model.StatusNew, true},
		{"Assigned", model.StatusAssigned, true},
		{"InProgress", model.StatusInProgress, true},
		{"Resolved", model.StatusResolved, true},
		{"Closed", model.StatusClosed, true},
		{"Cancelled", model.StatusCancelled, true},
		{"Invalid", model.TicketStatus("unknown"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.expected, tt.status.IsValid())
		})
	}
}

func TestTicketStatus_CanTransitionTo(t *testing.T) {
	tests := []struct {
		name     string
		from     model.TicketStatus
		to       model.TicketStatus
		expected bool
	}{
		{"New to Assigned", model.StatusNew, model.StatusAssigned, true},
		{"New to Cancelled", model.StatusNew, model.StatusCancelled, true},
		{"New to InProgress (Invalid)", model.StatusNew, model.StatusInProgress, false},
		{"Assigned to InProgress", model.StatusAssigned, model.StatusInProgress, true},
		{"InProgress to Resolved", model.StatusInProgress, model.StatusResolved, true},
		{"Resolved to Closed", model.StatusResolved, model.StatusClosed, true},
		{"Closed to New (Invalid)", model.StatusClosed, model.StatusNew, false},
		{"Unknown to New", model.TicketStatus("unknown"), model.StatusNew, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.expected, tt.from.CanTransitionTo(tt.to))
		})
	}
}

func TestTicket_Validate(t *testing.T) {
	now := time.Now()
	later := now.Add(2 * time.Hour)
	earlier := now.Add(-2 * time.Hour)

	validTicket := func() *model.Ticket {
		return &model.Ticket{
			Title:       "Valid Title",
			Description: "Valid Description",
			RequestorID: "req-1",
			Priority:    model.PriorityHigh,
			Status:      model.StatusNew,
			CreatedAt:   now,
			SLADueAt:    &later,
		}
	}

	tests := []struct {
		name        string
		modify      func(*model.Ticket)
		expectError bool
		errorMsg    string
	}{
		{"Valid", func(t *model.Ticket) {}, false, ""},
		{"Empty Title", func(t *model.Ticket) { t.Title = "   " }, true, "title is required"},
		{"Empty Description", func(t *model.Ticket) { t.Description = "" }, true, "description is required"},
		{"Empty Requestor", func(t *model.Ticket) { t.RequestorID = "" }, true, "requestor_id is required"},
		{"Invalid Priority", func(t *model.Ticket) { t.Priority = "invalid" }, true, "unknown priority 'invalid'"},
		{"Invalid Status", func(t *model.Ticket) { t.Status = "invalid" }, true, "unknown status 'invalid'"},
		{"Zero CreatedAt", func(t *model.Ticket) { t.CreatedAt = time.Time{} }, true, "created_at is required"},
		{"Nil SLADueAt", func(t *model.Ticket) { t.SLADueAt = nil }, true, "sla_due_at is required"},
		{"Zero SLADueAt", func(t *model.Ticket) { t.SLADueAt = &time.Time{} }, true, "sla_due_at is required"},
		{"SLADueAt before CreatedAt", func(t *model.Ticket) { t.SLADueAt = &earlier }, true, "cannot be before the ticket creation time"},
		{"Resolved but missing ResolvedAt", func(t *model.Ticket) {
			t.Status = model.StatusResolved
			t.ResolvedAt = nil
		}, true, "resolved_at is required"},
		{"Resolved with ResolvedAt before CreatedAt", func(t *model.Ticket) {
			t.Status = model.StatusResolved
			t.ResolvedAt = &earlier
		}, true, "resolved_at cannot be before created_at"},
		{"Cancelled but missing CancelledAt", func(t *model.Ticket) {
			t.Status = model.StatusCancelled
			t.CancelledAt = nil
		}, true, "cancelled_at is required"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ticket := validTicket()
			tt.modify(ticket)

			err := ticket.Validate()
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

func TestTicket_ValidateStatusTransition(t *testing.T) {
	now := time.Now()
	timestamp := now.Add(time.Hour)

	validTicket := func() *model.Ticket {
		return &model.Ticket{
			Status:    model.StatusNew,
			CreatedAt: now,
		}
	}

	tests := []struct {
		name          string
		modify        func(*model.Ticket)
		newStatus     model.TicketStatus
		reqAssigneeID string
		timestamp     time.Time
		expectError   bool
		errorMsg      string
	}{
		{
			name:          "Valid: New to Assigned",
			modify:        func(t *model.Ticket) {},
			newStatus:     model.StatusAssigned,
			reqAssigneeID: "assignee-1",
			timestamp:     timestamp,
			expectError:   false,
		},
		{
			name:          "Invalid: New to Assigned without AssigneeID",
			modify:        func(t *model.Ticket) {},
			newStatus:     model.StatusAssigned,
			reqAssigneeID: "",
			timestamp:     timestamp,
			expectError:   true,
			errorMsg:      "assignee_id is required",
		},
		{
			name: "Invalid: Change assignee during transition",
			modify: func(t *model.Ticket) {
				t.Status = model.StatusAssigned
				t.AssigneeID = "assignee-1"
			},
			newStatus:     model.StatusInProgress,
			reqAssigneeID: "assignee-2",
			timestamp:     timestamp,
			expectError:   true,
			errorMsg:      "cannot change assignee",
		},
		{
			name:          "Invalid: Same status",
			modify:        func(t *model.Ticket) {},
			newStatus:     model.StatusNew,
			reqAssigneeID: "",
			timestamp:     timestamp,
			expectError:   true,
			errorMsg:      "already set to",
		},
		{
			name:          "Invalid: Unknown status",
			modify:        func(t *model.Ticket) {},
			newStatus:     model.TicketStatus("unknown"),
			reqAssigneeID: "",
			timestamp:     timestamp,
			expectError:   true,
			errorMsg:      "unknown status",
		},
		{
			name:          "Invalid: Illegal transition",
			modify:        func(t *model.Ticket) {},
			newStatus:     model.StatusClosed,
			reqAssigneeID: "",
			timestamp:     timestamp,
			expectError:   true,
			errorMsg:      "cannot transition from",
		},
		{
			name: "Valid: To Resolved",
			modify: func(t *model.Ticket) {
				t.Status = model.StatusInProgress
				t.AssigneeID = "assignee-1"
			},
			newStatus:     model.StatusResolved,
			reqAssigneeID: "assignee-1",
			timestamp:     timestamp,
			expectError:   false,
		},
		{
			name: "Valid: To Cancelled",
			modify: func(t *model.Ticket) {
				t.Status = model.StatusNew
			},
			newStatus:     model.StatusCancelled,
			reqAssigneeID: "",
			timestamp:     timestamp,
			expectError:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ticket := validTicket()
			tt.modify(ticket)

			err := ticket.ValidateStatusTransition(tt.newStatus, tt.reqAssigneeID, tt.timestamp)
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
