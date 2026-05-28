package domain_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	domain "support-ticket.com/internal/model"
)

func TestTicketEvent_Validate(t *testing.T) {
	now := time.Now()

	validEvent := func() *domain.TicketEvent {
		return &domain.TicketEvent{
			TicketID:   1,
			FromStatus: domain.StatusNew,
			ToStatus:   domain.StatusAssigned,
			CreatedAt:  now,
		}
	}

	tests := []struct {
		name        string
		modify      func(*domain.TicketEvent)
		expectError bool
		errorMsg    string
	}{
		{"Valid", func(e *domain.TicketEvent) {}, false, ""},
		{"Zero TicketID", func(e *domain.TicketEvent) { e.TicketID = 0 }, true, "ticket_id is required"},
		{"Invalid FromStatus", func(e *domain.TicketEvent) { e.FromStatus = "invalid" }, true, "unknown from_status"},
		{"Invalid ToStatus", func(e *domain.TicketEvent) { e.ToStatus = "invalid" }, true, "unknown to_status"},
		{"Same Statuses", func(e *domain.TicketEvent) { e.ToStatus = domain.StatusNew }, true, "cannot be the same"},
		{"Illegal Transition", func(e *domain.TicketEvent) { e.ToStatus = domain.StatusClosed }, true, "illegal event transition"},
		{"Zero CreatedAt", func(e *domain.TicketEvent) { e.CreatedAt = time.Time{} }, true, "created_at is required"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			event := validEvent()
			tt.modify(event)

			err := event.Validate()
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

func TestTicketEvent_HashKey(t *testing.T) {
	event := &domain.TicketEvent{
		TicketID:   123,
		FromStatus: domain.StatusAssigned,
		ToStatus:   domain.StatusInProgress,
	}

	expectedHash := "123|assigned|in_progress"
	assert.Equal(t, expectedHash, event.HashKey())
}
