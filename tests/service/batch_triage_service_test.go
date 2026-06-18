package service_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/config"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/errmsgs"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/service"
	testmock "support-ticket.com/tests/mock"
)

// Mock AI Adapter for testing
type mockAIAdapter struct {
	mock.Mock
}

func (m *mockAIAdapter) AnalyzeTicket(ctx context.Context, data ai.TriagePromptData) (*ai.TriageResult, error) {
	args := m.Called(ctx, data)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*ai.TriageResult), args.Error(1)
}

func (m *mockAIAdapter) AnalyzeTicketWithVersion(ctx context.Context, data ai.TriagePromptData, promptVersion string) (*ai.TriageResult, error) {
	args := m.Called(ctx, data, promptVersion)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*ai.TriageResult), args.Error(1)
}

func (m *mockAIAdapter) Model() string {
	return "fake-model"
}	
func TestExecuteBatchTriage_Success(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	cfg := &config.Config{
		AIMaxBatchSize:   5,
		AIWorkerPoolSize: 2,
	}

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, cfg)

	ticket1 := model.Ticket{
		ID:          1,
		Title:       "Internet is not working",
		Description: "I cannot connect to the office wifi network.",
		Status:      model.StatusNew,
		Priority:    model.PriorityHigh,
	}

	ticket2 := model.Ticket{
		ID:          2,
		Title:       "Request for annual leave",
		Description: "I want to register leave for next week.",
		Status:      model.StatusAssigned,
		Priority:    model.PriorityLow,
	}

	tickets := []model.Ticket{ticket1, ticket2}
	ticketIDs := []uint{1, 2}

	// Mock DB fetching
	mockTicketRepo.On("FindByIds", mock.Anything, ticketIDs).Return(tickets, nil)

	// Mock Report fetching
	mockReportRepo.On("GetByDate", mock.Anything).Return(&model.TicketReport{}, nil)

	// Mock AI calls
	mockAI.On("AnalyzeTicket", mock.Anything, mock.MatchedBy(func(data ai.TriagePromptData) bool {
		return data.Ticket.ID == 1
	})).Return(&ai.TriageResult{
		Category:              "IT",
		UrgencyLevel:          "high",
		SLABreachRisk:         "medium",
		ReasonSummary:         "Network issue reported",
		RecommendedNextAction: "Assign to IT Support Team",
		ConfidenceScore:       0.9,
		FallbackUsed:          false,
		PromptVersion:         "v1.1",
	}, nil)

	mockAI.On("AnalyzeTicket", mock.Anything, mock.MatchedBy(func(data ai.TriagePromptData) bool {
		return data.Ticket.ID == 2
	})).Return(&ai.TriageResult{
		Category:              "HR",
		UrgencyLevel:          "low",
		SLABreachRisk:         "low",
		ReasonSummary:         "Leave request",
		RecommendedNextAction: "Assign to HR Manager",
		ConfidenceScore:       0.95,
		FallbackUsed:          false,
		PromptVersion:         "v1.1",
	}, nil)

	// Mock DB creation
	mockTriageRepo.On("Create", mock.Anything, mock.Anything).Return(nil)

	res, err := svc.ExecuteBatchTriage(context.Background(), ticketIDs)

	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Len(t, res.Processed, 2)
	assert.Len(t, res.Failed, 0)

	var res1, res2 *response.BatchTriageResponseItem
	for i := range res.Processed {
		item := &res.Processed[i]
		if item.TicketID == 1 {
			res1 = item
		} else if item.TicketID == 2 {
			res2 = item
		}
	}
	assert.NotNil(t, res1)
	assert.NotNil(t, res2)

	// Check ticket 1 result
	assert.Equal(t, uint(1), res1.TicketID)
	assert.Equal(t, "IT", res1.Category)
	assert.Equal(t, "high", res1.UrgencyLevel)
	assert.False(t, res1.FallbackUsed)

	// Check ticket 2 result
	assert.Equal(t, uint(2), res2.TicketID)
	assert.Equal(t, "HR", res2.Category)
	assert.Equal(t, "low", res2.UrgencyLevel)
	assert.False(t, res2.FallbackUsed)

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertExpectations(t)
	mockTriageRepo.AssertExpectations(t)
	mockAI.AssertExpectations(t)
}

func TestExecuteBatchTriage_EmptyBatch(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	cfg := &config.Config{
		AIMaxBatchSize:   5,
		AIWorkerPoolSize: 2,
	}

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, cfg)

	res, err := svc.ExecuteBatchTriage(context.Background(), []uint{})

	assert.Nil(t, res)
	assert.Error(t, err)
	assert.Equal(t, errmsgs.ErrEmptyBatch, err)
}

func TestExecuteBatchTriage_BatchTooLarge(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	cfg := &config.Config{
		AIMaxBatchSize:   2,
		AIWorkerPoolSize: 1,
	}

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, cfg)

	res, err := svc.ExecuteBatchTriage(context.Background(), []uint{1, 2, 3})

	assert.Nil(t, res)
	assert.Error(t, err)
	assert.Equal(t, errmsgs.ErrBatchTooLarge, err)
}

func TestExecuteBatchTriage_TicketNotFound(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	cfg := &config.Config{
		AIMaxBatchSize:   5,
		AIWorkerPoolSize: 2,
	}

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, cfg)

	ticketIDs := []uint{1, 2}

	// Only ticket 1 is returned from DB, meaning ticket 2 is missing
	tickets := []model.Ticket{
		{
			ID:          1,
			Title:       "Valid Ticket 1",
			Description: "I cannot connect to the office wifi network.",
			Status:      model.StatusNew,
			Priority:    model.PriorityHigh,
		},
	}

	mockTicketRepo.On("FindByIds", mock.Anything, ticketIDs).Return(tickets, nil)
	mockReportRepo.On("GetByDate", mock.Anything).Return(&model.TicketReport{}, nil)
	mockTriageRepo.On("Create", mock.Anything, mock.Anything).Return(nil)

	mockAI.On("AnalyzeTicket", mock.Anything, mock.Anything).Return(&ai.TriageResult{
		Category:        "IT",
		UrgencyLevel:    "high",
		ConfidenceScore: 0.9,
	}, nil)

	res, err := svc.ExecuteBatchTriage(context.Background(), ticketIDs)

	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Len(t, res.Processed, 1)
	assert.Len(t, res.Failed, 1)

	assert.Equal(t, uint(1), res.Processed[0].TicketID)
	assert.Equal(t, uint(2), res.Failed[0].TicketID)
	assert.Equal(t, errmsgs.ErrTicketNotFound.Message, res.Failed[0].Reason)

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertExpectations(t)
	mockTriageRepo.AssertExpectations(t)
	mockAI.AssertExpectations(t)
}

func TestExecuteBatchTriage_TerminalState(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	cfg := &config.Config{
		AIMaxBatchSize:   5,
		AIWorkerPoolSize: 2,
	}

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, cfg)

	ticketIDs := []uint{1, 2}

	tickets := []model.Ticket{
		{
			ID:          1,
			Title:       "Valid Ticket 1",
			Description: "I cannot connect to the office wifi network.",
			Status:      model.StatusNew,
			Priority:    model.PriorityHigh,
		},
		{
			ID:          2,
			Title:       "Terminal Ticket 2",
			Description: "This ticket has already been resolved.",
			Status:      model.StatusResolved, // Terminal state!
			Priority:    model.PriorityMedium,
		},
	}

	mockTicketRepo.On("FindByIds", mock.Anything, ticketIDs).Return(tickets, nil)
	mockReportRepo.On("GetByDate", mock.Anything).Return(&model.TicketReport{}, nil)
	mockTriageRepo.On("Create", mock.Anything, mock.Anything).Return(nil)

	mockAI.On("AnalyzeTicket", mock.Anything, mock.Anything).Return(&ai.TriageResult{
		Category:        "IT",
		UrgencyLevel:    "high",
		ConfidenceScore: 0.9,
	}, nil)

	res, err := svc.ExecuteBatchTriage(context.Background(), ticketIDs)

	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Len(t, res.Processed, 1)
	assert.Len(t, res.Failed, 1)

	assert.Equal(t, uint(1), res.Processed[0].TicketID)
	assert.Equal(t, uint(2), res.Failed[0].TicketID)
	assert.Equal(t, errmsgs.ErrTicketResolved.Message, res.Failed[0].Reason)

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertExpectations(t)
	mockTriageRepo.AssertExpectations(t)
	mockAI.AssertExpectations(t)
}

func TestExecuteBatchTriage_Fallback(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	cfg := &config.Config{
		AIMaxBatchSize:   5,
		AIWorkerPoolSize: 2,
	}

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, cfg)

	ticket1 := model.Ticket{
		ID:          1,
		Title:       "Printer is broken",
		Description: "The printer in office room 302 is not printing.",
		Status:      model.StatusNew,
		Priority:    model.PriorityMedium,
	}

	tickets := []model.Ticket{ticket1}
	ticketIDs := []uint{1}

	mockTicketRepo.On("FindByIds", mock.Anything, ticketIDs).Return(tickets, nil)
	mockReportRepo.On("GetByDate", mock.Anything).Return(&model.TicketReport{}, nil)

	// Mock AI fails (returns error) to trigger fallback
	mockAI.On("AnalyzeTicket", mock.Anything, mock.Anything).Return(nil, errors.New("rate limit exceeded"))

	// Mock DB creation of triage result (fallback classification creates it)
	mockTriageRepo.On("Create", mock.Anything, mock.Anything).Return(nil)

	res, err := svc.ExecuteBatchTriage(context.Background(), ticketIDs)

	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Len(t, res.Processed, 1)
	assert.Len(t, res.Failed, 0)

	assert.Equal(t, uint(1), res.Processed[0].TicketID)
	// Fallback should match "printer" as "IT" or generic, and fallback_used is true
	assert.True(t, res.Processed[0].FallbackUsed)
	assert.Equal(t, 0.0, res.Processed[0].ConfidenceScore)

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertExpectations(t)
	mockTriageRepo.AssertExpectations(t)
	mockAI.AssertExpectations(t)
}

func TestExecuteBatchTriage_TicketOverdue(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	cfg := &config.Config{
		AIMaxBatchSize:   5,
		AIWorkerPoolSize: 2,
	}

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, cfg)

	ticketIDs := []uint{1, 2}

	overdueTime := time.Now().Add(-1 * time.Hour)
	tickets := []model.Ticket{
		{
			ID:          1,
			Title:       "Valid Ticket 1",
			Description: "I cannot connect to the office wifi network.",
			Status:      model.StatusNew,
			Priority:    model.PriorityHigh,
		},
		{
			ID:          2,
			Title:       "Overdue Ticket 2",
			Description: "This ticket has run past its due date.",
			Status:      model.StatusNew,
			SLADueAt:    &overdueTime,
			Priority:    model.PriorityMedium,
		},
	}

	mockTicketRepo.On("FindByIds", mock.Anything, ticketIDs).Return(tickets, nil)
	mockReportRepo.On("GetByDate", mock.Anything).Return(&model.TicketReport{}, nil)
	mockTriageRepo.On("Create", mock.Anything, mock.Anything).Return(nil)

	mockAI.On("AnalyzeTicket", mock.Anything, mock.Anything).Return(&ai.TriageResult{
		Category:        "IT",
		UrgencyLevel:    "high",
		ConfidenceScore: 0.9,
	}, nil)

	res, err := svc.ExecuteBatchTriage(context.Background(), ticketIDs)

	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Len(t, res.Processed, 1)
	assert.Len(t, res.Failed, 1)

	assert.Equal(t, uint(1), res.Processed[0].TicketID)
	assert.Equal(t, uint(2), res.Failed[0].TicketID)
	assert.Equal(t, errmsgs.ErrTicketOverdue.Message, res.Failed[0].Reason)

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertExpectations(t)
	mockTriageRepo.AssertExpectations(t)
	mockAI.AssertExpectations(t)
}
