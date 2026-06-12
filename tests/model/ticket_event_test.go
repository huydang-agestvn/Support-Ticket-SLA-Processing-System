package domain_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"support-ticket.com/internal/model"
)

func TestTicketEvent_Validate(t *testing.T) {
	now := time.Now()

	validEvent := func() *model.TicketEvent {
		return &model.TicketEvent{
			TicketID:   1,
			FromStatus: model.StatusNew,
			ToStatus:   model.StatusAssigned,
			CreatedAt:  now,
		}
	}

	tests := []struct {
		name        string
		modify      func(*model.TicketEvent)
		expectError bool
		errorMsg    string
	}{
		{"Valid", func(e *model.TicketEvent) {}, false, ""},
		{"Zero TicketID", func(e *model.TicketEvent) { e.TicketID = 0 }, true, "ticket_id is required"},
		{"Invalid FromStatus", func(e *model.TicketEvent) { e.FromStatus = "invalid" }, true, "unknown from_status"},
		{"Invalid ToStatus", func(e *model.TicketEvent) { e.ToStatus = "invalid" }, true, "unknown to_status"},
		{"Same Statuses", func(e *model.TicketEvent) { e.ToStatus = model.StatusNew }, true, "cannot be the same"},
		{"Illegal Transition", func(e *model.TicketEvent) { e.ToStatus = model.StatusClosed }, true, "illegal event transition"},
		{"Zero CreatedAt", func(e *model.TicketEvent) { e.CreatedAt = time.Time{} }, true, "created_at is required"},
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
	event := &model.TicketEvent{
		TicketID:   123,
		FromStatus: model.StatusAssigned,
		ToStatus:   model.StatusInProgress,
	}

	expectedHash := "123|assigned|in_progress"
	assert.Equal(t, expectedHash, event.HashKey())
}
