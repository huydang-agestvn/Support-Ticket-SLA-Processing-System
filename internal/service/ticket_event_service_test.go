package service

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	domain "support-ticket.com/internal/model"
)

func TestTicketEventImport(t *testing.T) {
	ctx := context.Background()

	t.Run("SuccessSimpleImport", func(t *testing.T) {
		mockRepo := new(MockTicketRepository)
		mockEventRepo := new(MockTicketEventRepository)
		svc := NewTicketEventService(mockEventRepo, mockRepo)
		now := time.Now()
		events := []domain.TicketEvent{
			{
				TicketID:   1,
				FromStatus: domain.StatusNew,
				ToStatus:   domain.StatusAssigned,
				AssigneeID: "agent1",
				CreatedAt:  now,
			},
		}

		data, _ := json.Marshal(events)

		// Mocking metadata fetch
		mockRepo.On("GetExistingTicketIDs", ctx, []uint{1}).Return(map[uint]bool{1: true}, nil)
		mockRepo.On("GetTicketStatusAndCreatedAt", ctx, []uint{1}).Return(
			map[uint]domain.TicketStatus{1: domain.StatusNew},
			map[uint]time.Time{1: now.Add(-1 * time.Hour)},
			nil,
		)
		mockEventRepo.On("GetExistingEventKeys", ctx, mock.Anything).Return(map[string]bool{}, nil)

		// Mocking apply results
		mockEventRepo.On("CreateBatch", mock.Anything).Return(nil)
		mockRepo.On("UpdateStatusAndAssignee", ctx, uint(1), domain.StatusAssigned, "agent1").Return(nil)

		res, err := svc.Import(ctx, data)

		assert.NoError(t, err)
		assert.Equal(t, 1, res.AcceptedCount)
		assert.Equal(t, 0, res.RejectedCount)
		mockRepo.AssertExpectations(t)
		mockEventRepo.AssertExpectations(t)
	})

	t.Run("InvalidJSON", func(t *testing.T) {
		mockRepo := new(MockTicketRepository)
		mockEventRepo := new(MockTicketEventRepository)
		svc := NewTicketEventService(mockEventRepo, mockRepo)
		res, err := svc.Import(ctx, []byte("invalid"))
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "invalid JSON")
		assert.Equal(t, 0, res.AcceptedCount)
	})


	t.Run("EmptyBatch", func(t *testing.T) {
		mockRepo := new(MockTicketRepository)
		mockEventRepo := new(MockTicketEventRepository)
		svc := NewTicketEventService(mockEventRepo, mockRepo)
		res, err := svc.Import(ctx, []byte("[]"))
		assert.Error(t, err)
		assert.Equal(t, 0, res.AcceptedCount)
	})


	t.Run("RejectedNonExistentTicket", func(t *testing.T) {
		mockRepo := new(MockTicketRepository)
		mockEventRepo := new(MockTicketEventRepository)
		svc := NewTicketEventService(mockEventRepo, mockRepo)
		now := time.Now()
		events := []domain.TicketEvent{
			{
				TicketID:   999,
				FromStatus: domain.StatusNew,
				ToStatus:   domain.StatusAssigned,
				AssigneeID: "agent1",
				CreatedAt:  now,
			},
		}
		data, _ := json.Marshal(events)


		mockRepo.On("GetExistingTicketIDs", ctx, []uint{999}).Return(map[uint]bool{}, nil)
		mockRepo.On("GetTicketStatusAndCreatedAt", ctx, []uint{999}).Return(
			map[uint]domain.TicketStatus{},
			map[uint]time.Time{},
			nil,
		)
		mockEventRepo.On("GetExistingEventKeys", ctx, mock.Anything).Return(map[string]bool{}, nil)

		res, err := svc.Import(ctx, data)

		assert.NoError(t, err)
		assert.Equal(t, 0, res.AcceptedCount)
		assert.Equal(t, 1, res.RejectedCount)
		assert.Contains(t, res.RejectedDetails[0].ErrorName, "does not exist in DB")
	})

}
