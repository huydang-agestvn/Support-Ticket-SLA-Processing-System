package domain_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	domain "support-ticket.com/internal/model"
)

func TestPriority_IsValid(t *testing.T) {
	tests := []struct {
		name     string
		priority domain.Priority
		expected bool
	}{
		{"Low", domain.PriorityLow, true},
		{"Medium", domain.PriorityMedium, true},
		{"High", domain.PriorityHigh, true},
		{"Invalid", domain.Priority("critical"), false},
		{"Empty", domain.Priority(""), false},
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
		status   domain.TicketStatus
		expected bool
	}{
		{"New", domain.StatusNew, true},
		{"Assigned", domain.StatusAssigned, true},
		{"InProgress", domain.StatusInProgress, true},
		{"Resolved", domain.StatusResolved, true},
		{"Closed", domain.StatusClosed, true},
		{"Cancelled", domain.StatusCancelled, true},
		{"Invalid", domain.TicketStatus("unknown"), false},
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
		from     domain.TicketStatus
		to       domain.TicketStatus
		expected bool
	}{
		{"New to Assigned", domain.StatusNew, domain.StatusAssigned, true},
		{"New to Cancelled", domain.StatusNew, domain.StatusCancelled, true},
		{"New to InProgress (Invalid)", domain.StatusNew, domain.StatusInProgress, false},
		{"Assigned to InProgress", domain.StatusAssigned, domain.StatusInProgress, true},
		{"InProgress to Resolved", domain.StatusInProgress, domain.StatusResolved, true},
		{"Resolved to Closed", domain.StatusResolved, domain.StatusClosed, true},
		{"Closed to New (Invalid)", domain.StatusClosed, domain.StatusNew, false},
		{"Unknown to New", domain.TicketStatus("unknown"), domain.StatusNew, false},
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

	validTicket := func() *domain.Ticket {
		return &domain.Ticket{
			Title:       "Valid Title",
			Description: "Valid Description",
			RequestorID: "req-1",
			Priority:    domain.PriorityHigh,
			Status:      domain.StatusNew,
			CreatedAt:   now,
			SLADueAt:    &later,
		}
	}

	tests := []struct {
		name        string
		modify      func(*domain.Ticket)
		expectError bool
		errorMsg    string
	}{
		{"Valid", func(t *domain.Ticket) {}, false, ""},
		{"Empty Title", func(t *domain.Ticket) { t.Title = "   " }, true, "title is required"},
		{"Empty Description", func(t *domain.Ticket) { t.Description = "" }, true, "description is required"},
		{"Empty Requestor", func(t *domain.Ticket) { t.RequestorID = "" }, true, "requestor_id is required"},
		{"Invalid Priority", func(t *domain.Ticket) { t.Priority = "invalid" }, true, "unknown priority 'invalid'"},
		{"Invalid Status", func(t *domain.Ticket) { t.Status = "invalid" }, true, "unknown status 'invalid'"},
		{"Zero CreatedAt", func(t *domain.Ticket) { t.CreatedAt = time.Time{} }, true, "created_at is required"},
		{"Nil SLADueAt", func(t *domain.Ticket) { t.SLADueAt = nil }, true, "sla_due_at is required"},
		{"Zero SLADueAt", func(t *domain.Ticket) { t.SLADueAt = &time.Time{} }, true, "sla_due_at is required"},
		{"SLADueAt before CreatedAt", func(t *domain.Ticket) { t.SLADueAt = &earlier }, true, "cannot be before the ticket creation time"},
		{"Resolved but missing ResolvedAt", func(t *domain.Ticket) {
			t.Status = domain.StatusResolved
			t.ResolvedAt = nil
		}, true, "resolved_at is required"},
		{"Resolved with ResolvedAt before CreatedAt", func(t *domain.Ticket) {
			t.Status = domain.StatusResolved
			t.ResolvedAt = &earlier
		}, true, "resolved_at cannot be before created_at"},
		{"Cancelled but missing CancelledAt", func(t *domain.Ticket) {
			t.Status = domain.StatusCancelled
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

	validTicket := func() *domain.Ticket {
		return &domain.Ticket{
			Status:    domain.StatusNew,
			CreatedAt: now,
		}
	}

	tests := []struct {
		name          string
		modify        func(*domain.Ticket)
		newStatus     domain.TicketStatus
		reqAssigneeID string
		timestamp     time.Time
		expectError   bool
		errorMsg      string
	}{
		{
			name:          "Valid: New to Assigned",
			modify:        func(t *domain.Ticket) {},
			newStatus:     domain.StatusAssigned,
			reqAssigneeID: "assignee-1",
			timestamp:     timestamp,
			expectError:   false,
		},
		{
			name:          "Invalid: New to Assigned without AssigneeID",
			modify:        func(t *domain.Ticket) {},
			newStatus:     domain.StatusAssigned,
			reqAssigneeID: "",
			timestamp:     timestamp,
			expectError:   true,
			errorMsg:      "assignee_id is required",
		},
		{
			name: "Invalid: Change assignee during transition",
			modify: func(t *domain.Ticket) {
				t.Status = domain.StatusAssigned
				t.AssigneeID = "assignee-1"
			},
			newStatus:     domain.StatusInProgress,
			reqAssigneeID: "assignee-2",
			timestamp:     timestamp,
			expectError:   true,
			errorMsg:      "cannot change assignee",
		},
		{
			name:          "Invalid: Same status",
			modify:        func(t *domain.Ticket) {},
			newStatus:     domain.StatusNew,
			reqAssigneeID: "",
			timestamp:     timestamp,
			expectError:   true,
			errorMsg:      "already set to",
		},
		{
			name:          "Invalid: Unknown status",
			modify:        func(t *domain.Ticket) {},
			newStatus:     domain.TicketStatus("unknown"),
			reqAssigneeID: "",
			timestamp:     timestamp,
			expectError:   true,
			errorMsg:      "unknown status",
		},
		{
			name:          "Invalid: Illegal transition",
			modify:        func(t *domain.Ticket) {},
			newStatus:     domain.StatusClosed,
			reqAssigneeID: "",
			timestamp:     timestamp,
			expectError:   true,
			errorMsg:      "cannot transition from",
		},
		{
			name: "Valid: To Resolved",
			modify: func(t *domain.Ticket) {
				t.Status = domain.StatusInProgress
				t.AssigneeID = "assignee-1"
			},
			newStatus:     domain.StatusResolved,
			reqAssigneeID: "assignee-1",
			timestamp:     timestamp,
			expectError:   false,
		},
		{
			name: "Valid: To Cancelled",
			modify: func(t *domain.Ticket) {
				t.Status = domain.StatusNew
			},
			newStatus:     domain.StatusCancelled,
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
