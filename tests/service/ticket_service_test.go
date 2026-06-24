package service_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/errmsgs"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/service"
	testmock "support-ticket.com/tests/mock"
)

func TestTicketService_Create(t *testing.T) {
	ctx := context.Background()
	dueAt := time.Now().Add(2 * time.Hour)

	tests := []struct {
		name          string
		req           request.CreateTicketReq
		mockRepo      func(*testmock.MockTicketRepository)
		expectedError string
		expectedTitle string
	}{
		{
			name: "Success",
			req: request.CreateTicketReq{
				RequestorID: "user1",
				Title:       "Test Ticket",
				Description: "Description",
				Priority:    model.PriorityHigh,
				Category:    model.CategoryIT,
				SlaDueAt:    &dueAt,
			},
			mockRepo: func(m *testmock.MockTicketRepository) {
				m.On("Create", ctx, mock.AnythingOfType("*model.Ticket")).Return(nil)
			},
		},
		{
			name: "TrimsWhitespace",
			req: request.CreateTicketReq{
				RequestorID: "user1",
				Title:       "VPN failed!                   ",
				Description: "  Please help me check the VPN connection.  ",
				Priority:    model.PriorityHigh,
				Category:    model.CategoryIT,
				SlaDueAt:    &dueAt,
			},
			mockRepo: func(m *testmock.MockTicketRepository) {
				m.On("Create", ctx, mock.AnythingOfType("*model.Ticket")).Return(nil)
			},
			expectedTitle: "VPN failed!",
		},
		{
			name: "DBError",
			req: request.CreateTicketReq{
				RequestorID: "user1",
				Title:       "Test Ticket",
				Description: "Description",
				Priority:    model.PriorityHigh,
				Category:    model.CategoryIT,
				SlaDueAt:    &dueAt,
			},
			mockRepo: func(m *testmock.MockTicketRepository) {
				m.On("Create", ctx, mock.Anything).Return(errors.New("db error"))
			},
			expectedError: "db error",
		},
		{
			name: "ValidationError",
			req: request.CreateTicketReq{
				RequestorID: "user1",
				Description: "Description",
				Priority:    model.PriorityHigh,
				Category:    model.CategoryIT,
				SlaDueAt:    &dueAt,
			},
			mockRepo:      func(m *testmock.MockTicketRepository) {},
			expectedError: "title is required",
		},
		{
			name: "ContentSafetyBlocked",
			req: request.CreateTicketReq{
				RequestorID: "user1",
				Title:       "You are stupid",
				Description: "Fix this internal support request now.",
				Priority:    model.PriorityLow,
				Category:    model.CategoryIT,
				SlaDueAt:    &dueAt,
			},
			mockRepo:      func(m *testmock.MockTicketRepository) {},
			expectedError: "ticket content blocked by safety filter: insult",
		},
		{
			name: "ContentSafetyBlockedTitleGibberish",
			req: request.CreateTicketReq{
				RequestorID: "user1",
				Title:       "VPN failed!  ư    d            ",
				Description: "Please help me check the VPN connection.",
				Priority:    model.PriorityLow,
				Category:    model.CategoryIT,
				SlaDueAt:    &dueAt,
			},
			mockRepo:      func(m *testmock.MockTicketRepository) {},
			expectedError: "ticket content blocked by safety filter: gibberish",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockRepo := new(testmock.MockTicketRepository)
			mockEventRepo := new(testmock.MockTicketEventRepository)
			tt.mockRepo(mockRepo)

			svc := service.NewTicketService(mockRepo, mockEventRepo)
			res, err := svc.Create(ctx, tt.req)

			if tt.expectedError != "" {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.expectedError)
				assert.Nil(t, res)
				if tt.name == "ContentSafetyBlocked" {
					var apiErr *common.Error
					assert.ErrorAs(t, err, &apiErr)
					assert.Equal(t, common.ErrCodeTicketContentBlocked, apiErr.Code)
					mockRepo.AssertNotCalled(t, "Create", mock.Anything, mock.Anything)
				}
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, res)
				expectedTitle := tt.expectedTitle
				if expectedTitle == "" {
					expectedTitle = tt.req.Title
				}
				assert.Equal(t, expectedTitle, res.Title)
				assert.Equal(t, model.StatusNew, res.Status)
				assert.NotNil(t, res.SLADueAt)
			}
			mockRepo.AssertExpectations(t)
		})
	}
}

func TestTicketService_FindById(t *testing.T) {
	ticket := &model.Ticket{ID: 1, Title: "Test", RequestorID: "user-123", Category: model.CategoryIT}

	tests := []struct {
		name          string
		id            uint
		currentUser   auth.UserPrincipal
		mockRepo      func(context.Context, *testmock.MockTicketRepository)
		expectedRes   *model.Ticket
		expectedError error
	}{
		{
			name: "Success_RequestorOwnsTicket",
			id:   1,
			currentUser: auth.UserPrincipal{
				UserID: "user-123",
				Roles:  []string{auth.RoleRequestor},
			},
			mockRepo: func(ctx context.Context, m *testmock.MockTicketRepository) {
				m.On("FindById", ctx, uint(1)).Return(ticket, nil)
			},
			expectedRes:   ticket,
			expectedError: nil,
		},
		{
			name: "Success_AgentViewsAnyTicket",
			id:   1,
			currentUser: auth.UserPrincipal{
				UserID: "agent-456",
				Roles:  []string{auth.RoleAgent},
			},
			mockRepo: func(ctx context.Context, m *testmock.MockTicketRepository) {
				m.On("FindById", ctx, uint(1)).Return(ticket, nil)
			},
			expectedRes:   ticket,
			expectedError: nil,
		},
		{
			name: "Success_ManagerViewsAnyTicket",
			id:   1,
			currentUser: auth.UserPrincipal{
				UserID: "manager-789",
				Roles:  []string{auth.RoleManager},
			},
			mockRepo: func(ctx context.Context, m *testmock.MockTicketRepository) {
				m.On("FindById", ctx, uint(1)).Return(ticket, nil)
			},
			expectedRes:   ticket,
			expectedError: nil,
		},
		{
			name: "Unauthorized_RequestorViewsOtherTicket",
			id:   1,
			currentUser: auth.UserPrincipal{
				UserID: "user-other",
				Roles:  []string{auth.RoleRequestor},
			},
			mockRepo: func(ctx context.Context, m *testmock.MockTicketRepository) {
				m.On("FindById", ctx, uint(1)).Return(ticket, nil)
			},
			expectedRes:   nil,
			expectedError: errmsgs.ErrUnauthorizedToViewTicket,
		},
		{
			name: "NotFound",
			id:   1,
			currentUser: auth.UserPrincipal{
				UserID: "user-123",
				Roles:  []string{auth.RoleRequestor},
			},
			mockRepo: func(ctx context.Context, m *testmock.MockTicketRepository) {
				m.On("FindById", ctx, uint(1)).Return((*model.Ticket)(nil), nil)
			},
			expectedRes:   nil,
			expectedError: errmsgs.ErrTicketNotFound,
		},
		{
			name: "DBError",
			id:   1,
			currentUser: auth.UserPrincipal{
				UserID: "user-123",
				Roles:  []string{auth.RoleRequestor},
			},
			mockRepo: func(ctx context.Context, m *testmock.MockTicketRepository) {
				m.On("FindById", ctx, uint(1)).Return(nil, errors.New("db error"))
			},
			expectedRes:   nil,
			expectedError: errors.New("failed to get ticket from db: db error"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockRepo := new(testmock.MockTicketRepository)
			mockEventRepo := new(testmock.MockTicketEventRepository)

			ctx := auth.WithUser(context.Background(), tt.currentUser)
			tt.mockRepo(ctx, mockRepo)

			svc := service.NewTicketService(mockRepo, mockEventRepo)
			res, err := svc.FindById(ctx, tt.id)

			if tt.expectedError != nil {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.expectedError.Error())
				assert.Nil(t, res)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.expectedRes, res)
			}
			mockRepo.AssertExpectations(t)
		})
	}
}

func TestTicketService_UpdateTicketStatus(t *testing.T) {
	ctx := context.Background()

	tests := []struct {
		name          string
		id            uint
		req           request.UpdateStatusReq
		mockRepo      func(*testmock.MockTicketRepository)
		expectedError string
	}{
		{
			name: "Success",
			id:   1,
			req: request.UpdateStatusReq{
				Status:     model.StatusInProgress,
				AssigneeID: "agent1",
			},
			mockRepo: func(m *testmock.MockTicketRepository) {
				ticket := &model.Ticket{
					ID:         1,
					Status:     model.StatusAssigned,
					AssigneeID: "agent1",
					Category:   model.CategoryIT,
				}
				m.On("FindById", ctx, uint(1)).Return(ticket, nil)
				m.On("UpdateStatusWithEvent", ctx, mock.Anything, mock.Anything).Return(nil)
			},
			expectedError: "",
		},
		{
			name: "ValidationError_InvalidTransition",
			id:   1,
			req: request.UpdateStatusReq{
				Status:     model.StatusInProgress,
				AssigneeID: "agent1",
			},
			mockRepo: func(m *testmock.MockTicketRepository) {
				ticket := &model.Ticket{
					ID:         1,
					Status:     model.StatusNew,
					AssigneeID: "agent1",
					Category:   model.CategoryIT,
				}
				m.On("FindById", ctx, uint(1)).Return(ticket, nil)
			},
			expectedError: "cannot transition from 'new' to 'in_progress'",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockRepo := new(testmock.MockTicketRepository)
			mockEventRepo := new(testmock.MockTicketEventRepository)
			tt.mockRepo(mockRepo)

			svc := service.NewTicketService(mockRepo, mockEventRepo)
			err := svc.UpdateTicketStatus(ctx, tt.id, tt.req)

			if tt.expectedError != "" {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.expectedError)
			} else {
				assert.NoError(t, err)
			}
			mockRepo.AssertExpectations(t)
		})
	}
}

func TestTicketService_FindAll(t *testing.T) {
	ctx := context.Background()

	tests := []struct {
		name        string
		filter      request.TicketFilter
		paging      common.PaginationQuery
		mockRepo    func(*testmock.MockTicketRepository)
		expectedRes *common.PaginatedResult[model.Ticket]
	}{
		{
			name:   "Success",
			filter: request.TicketFilter{},
			paging: common.PaginationQuery{Page: 1, Limit: 10},
			mockRepo: func(m *testmock.MockTicketRepository) {
				tickets := []model.Ticket{{ID: 1, Title: "Test"}}
				m.On("FindAll", ctx, request.TicketFilter{}, 0, 10).Return(tickets, int64(1), nil)
			},
			expectedRes: &common.PaginatedResult[model.Ticket]{
				Items:      []model.Ticket{{ID: 1, Title: "Test"}},
				Total:      1,
				Page:       1,
				Limit:      10,
				TotalPages: 1,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockRepo := new(testmock.MockTicketRepository)
			mockEventRepo := new(testmock.MockTicketEventRepository)
			tt.mockRepo(mockRepo)

			svc := service.NewTicketService(mockRepo, mockEventRepo)
			res, err := svc.FindAll(ctx, tt.filter, tt.paging)

			assert.NoError(t, err)
			assert.Equal(t, tt.expectedRes.Items, res.Items)
			assert.Equal(t, tt.expectedRes.Total, res.Total)
			assert.Equal(t, tt.expectedRes.Page, res.Page)
			mockRepo.AssertExpectations(t)
		})
	}
}
