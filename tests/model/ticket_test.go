package domain_test

import (
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	_ "support-ticket.com/internal/ai"
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
			Title:       "This is a valid ticket title with enough length",
			Description: "This is a valid description that is long enough to pass the validation check of fifty characters limit.",
			RequestorID: "req-1",
			Priority:    model.PriorityHigh,
			Category:    model.CategoryIT,
			Status:      model.StatusNew,
			AuditModel: model.AuditModel{
				CreatedAt: now,
			},
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
		{"Short Title", func(t *model.Ticket) { t.Title = "Too short title" }, true, "at least 20 characters long"},
		{"Long Title", func(t *model.Ticket) { t.Title = strings.Repeat("A", 201) }, true, "cannot exceed 200 characters"},
		{"Empty Description", func(t *model.Ticket) { t.Description = "" }, true, "description is required"},
		{"Short Description", func(t *model.Ticket) { t.Description = "Too short" }, true, "at least 50 characters long"},
		{"Long Description", func(t *model.Ticket) { t.Description = strings.Repeat("A", 501) }, true, "cannot exceed 500 characters"},
		{"Empty Requestor", func(t *model.Ticket) { t.RequestorID = "" }, true, "requestor_id is required"},
		{"Invalid Priority", func(t *model.Ticket) { t.Priority = "invalid" }, true, "unknown priority 'invalid'"},
		{"Invalid Category", func(t *model.Ticket) { t.Category = "invalid" }, true, "unknown category 'invalid'"},
		{"Empty Category", func(t *model.Ticket) { t.Category = "" }, true, "unknown category ''"},
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
			AuditModel: model.AuditModel{
				CreatedAt: now,
			},
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

func TestTicket_ValidateRoomAndFloor(t *testing.T) {
	now := time.Now()
	later := now.Add(2 * time.Hour)

	validTicket := func(title, desc string) *model.Ticket {
		return &model.Ticket{
			Title:       title,
			Description: desc,
			RequestorID: "req-1",
			Priority:    model.PriorityHigh,
			Category:    model.CategoryIT,
			Status:      model.StatusNew,
			AuditModel: model.AuditModel{
				CreatedAt: now,
			},
			SLADueAt:    &later,
		}
	}

	tests := []struct {
		name        string
		title       string
		description string
		expectError bool
		errorMsg    string
	}{
		{
			name:        "Bypass: No room or floor specified",
			title:       "This is a general support ticket with no location info",
			description: "Please help me install the latest software updates on my corporate laptop as soon as possible.",
			expectError: false,
		},
		{
			name:        "Bypass: Only floor specified",
			title:       "Network issue reported on Floor 18",
			description: "We are experiencing a network connection drop for multiple workstations near the East windows.",
			expectError: false,
		},
		{
			name:        "Bypass: Only room specified",
			title:       "Printer not printing in office room 302",
			description: "The main printer appears offline. Standard printing tasks are queued but not processing.",
			expectError: false,
		},
		{
			name:        "Valid: Numbered room on correct floor",
			title:       "Broken monitor in Room 18A on Floor 18",
			description: "Please replace the second monitor. The display panel is flickering continuously.",
			expectError: false,
		},
		{
			name:        "Valid: Numbered room with large digits",
			title:       "Access point failure on Floor 18",
			description: "Employees in Room 1805 are unable to connect to the Wi-Fi. Please check the switch.",
			expectError: false,
		},
		{
			name:        "Valid: Named room on correct floor",
			title:       "Executive boardroom pantry needs coffee refilled",
			description: "We have an upcoming meeting on Floor 12A and the boardroom pantry is low on coffee.",
			expectError: false,
		},
		{
			name:        "Invalid: Numbered room on mismatching floor",
			title:       "Water leak in Room 19B on Floor 18",
			description: "Water is dripping from the ceiling. We need urgent building maintenance to fix this.",
			expectError: true,
			errorMsg:    "room and floor mismatch: room '19b' is not compatible with floor '18'",
		},
		{
			name:        "Invalid: Named room on mismatching floor",
			title:       "Lobby carpet stain reported on Floor 19",
			description: "There is a coffee spill in the reception lobby. Please coordinate cleaning.",
			expectError: true,
			errorMsg:    "room and floor mismatch: room 'lobby' is not compatible with floor '19'",
		},
		{
			name:        "Invalid: Floor does not exist",
			title:       "Network printer driver installation and mapping request for floor 20",
			description: "I recently relocated my desk to Floor 19 and I need my laptop mapped to the main department printer (Model HP Laserjet 500) so I can print physical contracts.",
			expectError: true,
			errorMsg:    "invalid floor or room",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ticket := validTicket(tt.title, tt.description)
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

