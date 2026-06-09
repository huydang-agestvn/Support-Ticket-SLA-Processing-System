package service_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/service"
	testmock "support-ticket.com/tests/mock"
)

type MockAuditLogger struct {
	mock.Mock
}

func (m *MockAuditLogger) WriteAuditLog(records []service.AuditLogRecord, userID string) (string, error) {
	args := m.Called(records, userID)
	return args.String(0), args.Error(1)
}

func (m *MockAuditLogger) GetAuditLogPath(filename string) (string, error) {
	args := m.Called(filename)
	return args.String(0), args.Error(1)
}

func TestTicketEventService_Import(t *testing.T) {
	ctx := context.Background()
	user := auth.UserPrincipal{
		UserID:   "test-user-id",
		Username: "test-user",
	}
	ctx = auth.WithUser(ctx, user)
	
	now := time.Now()

	validEvent := model.TicketEvent{
		TicketID:   1,
		FromStatus: model.StatusNew,
		ToStatus:   model.StatusAssigned,
		AssigneeID: "agent1",
		CreatedAt:  now,
	}

	invalidTransitionEvent := model.TicketEvent{
		TicketID:   2,
		FromStatus: model.StatusNew,
		ToStatus:   model.StatusNew, // Invalid transition
		AssigneeID: "agent1",
		CreatedAt:  now,
	}

	nonExistentTicketEvent := model.TicketEvent{
		TicketID:   999,
		FromStatus: model.StatusNew,
		ToStatus:   model.StatusAssigned,
		AssigneeID: "agent1",
		CreatedAt:  now,
	}

	tests := []struct {
		name                 string
		inputEvents          []model.TicketEvent
		mockRepo             func(*testmock.MockTicketRepository)
		mockEventRepo        func(*testmock.MockTicketEventRepository)
		expectedError        string
		expectedAccepted     int
		expectedRejected     int
		expectedRejectDetail string
	}{
		{
			name:        "SuccessSimpleImport",
			inputEvents: []model.TicketEvent{validEvent},
			mockRepo: func(m *testmock.MockTicketRepository) {
				m.On("GetExistingTicketIDs", ctx, []uint{1}).Return(map[uint]bool{1: true}, nil)
				m.On("GetTicketStatusAndCreatedAt", ctx, []uint{1}).Return(
					map[uint]model.TicketStatus{1: model.StatusNew},
					map[uint]time.Time{1: now.Add(-1 * time.Hour)},
					map[uint]string{1: ""},
					nil,
				)
				m.On("Transaction", ctx, mock.Anything).Return(nil)
				m.On("UpdateStatusesBatch", mock.Anything, mock.MatchedBy(func(tickets []model.Ticket) bool {
					return len(tickets) == 1 && tickets[0].AssigneeID == "agent1" && tickets[0].Status == model.StatusAssigned
				})).Return(nil)
			},
			mockEventRepo: func(m *testmock.MockTicketEventRepository) {
				m.On("GetExistingEventKeys", ctx, mock.Anything).Return(map[string]bool{}, nil)
				m.On("CreateBatch", mock.Anything, mock.Anything).Return(nil)
			},
			expectedAccepted: 1,
			expectedRejected: 0,
		},
		{
			name:             "EmptyBatch",
			inputEvents:      []model.TicketEvent{},
			mockRepo:         func(m *testmock.MockTicketRepository) {},
			mockEventRepo:    func(m *testmock.MockTicketEventRepository) {},
			expectedError:    "batch is empty",
			expectedAccepted: 0,
			expectedRejected: 0,
		},
		{
			name:        "RejectedNonExistentTicket",
			inputEvents: []model.TicketEvent{nonExistentTicketEvent},
			mockRepo: func(m *testmock.MockTicketRepository) {
				m.On("GetExistingTicketIDs", ctx, []uint{999}).Return(map[uint]bool{}, nil)
				m.On("GetTicketStatusAndCreatedAt", ctx, []uint{999}).Return(
					map[uint]model.TicketStatus{},
					map[uint]time.Time{},
					map[uint]string{},
					nil,
				)
				m.On("Transaction", ctx, mock.Anything).Return(nil)
			},
			mockEventRepo: func(m *testmock.MockTicketEventRepository) {
				m.On("GetExistingEventKeys", ctx, mock.Anything).Return(map[string]bool{}, nil)
			},
			expectedAccepted:     0,
			expectedRejected:     1,
			expectedRejectDetail: "does not exist in DB",
		},
		{
			name:        "ValidationError",
			inputEvents: []model.TicketEvent{invalidTransitionEvent},
			mockRepo: func(m *testmock.MockTicketRepository) {
				m.On("GetExistingTicketIDs", ctx, []uint(nil)).Return(map[uint]bool{}, nil)
				m.On("GetTicketStatusAndCreatedAt", ctx, []uint(nil)).Return(
					map[uint]model.TicketStatus{},
					map[uint]time.Time{},
					map[uint]string{},
					nil,
				)
				m.On("Transaction", ctx, mock.Anything).Return(nil)
			},
			mockEventRepo: func(m *testmock.MockTicketEventRepository) {
				m.On("GetExistingEventKeys", ctx, mock.Anything).Return(map[string]bool{}, nil)
			},
			expectedAccepted:     0,
			expectedRejected:     1,
			expectedRejectDetail: "from_status and to_status cannot be the same",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockRepo := new(testmock.MockTicketRepository)
			mockEventRepo := new(testmock.MockTicketEventRepository)
			mockAuditLogger := new(MockAuditLogger)

			tt.mockRepo(mockRepo)
			tt.mockEventRepo(mockEventRepo)

			if tt.expectedRejectDetail != "" {
				mockAuditLogger.On("WriteAuditLog", mock.Anything, mock.Anything).Return("mock_audit.csv", nil)
			}

			svc := service.NewTicketEventService(mockEventRepo, mockRepo, mockAuditLogger)
			res, err := svc.Import(ctx, tt.inputEvents)

			if tt.expectedError != "" {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.expectedError)
				assert.Empty(t, res)
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, res)
				assert.Equal(t, tt.expectedAccepted, res.AcceptedCount)
				assert.Equal(t, tt.expectedRejected, res.RejectedCount)
				if tt.expectedRejectDetail != "" {
					assert.Equal(t, "mock_audit.csv", res.AuditLogFile)
				} else {
					assert.Empty(t, res.AuditLogFile)
				}
			}

			mockRepo.AssertExpectations(t)
			mockEventRepo.AssertExpectations(t)
			mockAuditLogger.AssertExpectations(t)
		})
	}
}
