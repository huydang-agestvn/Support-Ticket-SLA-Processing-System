package service_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"support-ticket.com/internal/config"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/service"
	testmock "support-ticket.com/tests/mock"
)

func TestExecuteTriage_BlocksUnsafeContentBeforeAI(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, nil, mockAI, nil, &config.Config{})

	ticket := &model.Ticket{
		ID:          1,
		RequestorID: "user-1",
		Title:       "You are stupid",
		Description: "Fix this internal support request now.",
		Status:      model.StatusNew,
		Priority:    model.PriorityHigh,
	}

	mockTicketRepo.On("FindById", mock.Anything, uint(1)).Return(ticket, nil)

	res, err := svc.ExecuteTriage(context.Background(), 1)

	assert.Nil(t, res)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "ticket content blocked by safety filter: insult")

	var apiErr *common.Error
	assert.ErrorAs(t, err, &apiErr)
	assert.Equal(t, common.ErrCodeTicketContentBlocked, apiErr.Code)

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertNotCalled(t, "GetByDate", mock.Anything)
	mockAI.AssertNotCalled(t, "AnalyzeTicket", mock.Anything, mock.Anything)
	mockTriageRepo.AssertNotCalled(t, "Create", mock.Anything, mock.Anything)
}

func TestExecuteBatchTriage_BlocksUnsafeContentAsFailedItem(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	cfg := &config.Config{
		AIMaxBatchSize:   5,
		AIWorkerPoolSize: 2,
	}
	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, nil, mockAI, nil, cfg)

	ticketIDs := []uint{1}
	tickets := []model.Ticket{
		{
			ID:          1,
			RequestorID: "user-1",
			Title:       "aaaaaaa",
			Description: "!!!!!",
			Status:      model.StatusNew,
			Priority:    model.PriorityHigh,
		},
	}

	mockTicketRepo.On("FindByIds", mock.Anything, ticketIDs).Return(tickets, nil)

	res, err := svc.ExecuteBatchTriage(context.Background(), ticketIDs)

	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Len(t, res.Processed, 0)
	assert.Len(t, res.Failed, 1)
	assert.Equal(t, uint(1), res.Failed[0].TicketID)
	assert.Equal(t, "ticket content blocked by safety filter: gibberish", res.Failed[0].Reason)

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertNotCalled(t, "GetByDate", mock.Anything)
	mockAI.AssertNotCalled(t, "AnalyzeTicket", mock.Anything, mock.Anything)
	mockTriageRepo.AssertNotCalled(t, "Create", mock.Anything, mock.Anything)
}
