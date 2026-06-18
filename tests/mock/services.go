package mock

import (
	"context"
	"time"

	"github.com/stretchr/testify/mock"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/model"
)

// MockReportService
type MockReportService struct {
	mock.Mock
}

func (m *MockReportService) GenerateReport(date time.Time) (*model.TicketReport, error) {
	args := m.Called(date)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.TicketReport), args.Error(1)
}

func (m *MockReportService) GetReport(date time.Time) (*model.TicketReport, error) {
	args := m.Called(date)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.TicketReport), args.Error(1)
}

// MockTicketService
type MockTicketService struct {
	mock.Mock
}

func (m *MockTicketService) Create(ctx context.Context, req request.CreateTicketReq) (*model.Ticket, error) {
	args := m.Called(ctx, req)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.Ticket), args.Error(1)
}

func (m *MockTicketService) FindById(ctx context.Context, id uint) (*model.Ticket, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.Ticket), args.Error(1)
}

func (m *MockTicketService) FindAll(ctx context.Context, filter request.TicketFilter, paging common.PaginationQuery) (*common.PaginatedResult[model.Ticket], error) {
	args := m.Called(ctx, filter, paging)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*common.PaginatedResult[model.Ticket]), args.Error(1)
}

func (m *MockTicketService) UpdateTicketStatus(ctx context.Context, id uint, req request.UpdateStatusReq) error {
	args := m.Called(ctx, id, req)
	return args.Error(0)
}

// MockTicketEventService
type MockTicketEventService struct {
	mock.Mock
}

func (m *MockTicketEventService) Import(ctx context.Context, events []model.TicketEvent) (model.BatchImportResult, error) {
	args := m.Called(ctx, events)
	return args.Get(0).(model.BatchImportResult), args.Error(1)
}

// MockAuthService
type MockAuthService struct {
	mock.Mock
}

func (m *MockAuthService) Login(input request.LoginRequest) (*response.LoginResponse, error) {
	args := m.Called(input)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*response.LoginResponse), args.Error(1)
}

// MockTriageService
type MockTriageService struct {
	mock.Mock
}

func (m *MockTriageService) ExecuteTriage(ctx context.Context, ticketID uint) (*response.TriageResponse, error) {
	args := m.Called(ctx, ticketID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*response.TriageResponse), args.Error(1)
}

func (m *MockTriageService) ExecuteBatchTriage(ctx context.Context, ticketIDs []uint) (*response.BatchTriageResponse, error) {
	args := m.Called(ctx, ticketIDs)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*response.BatchTriageResponse), args.Error(1)
}

func (m *MockTriageService) GetLatestTriageResult(ctx context.Context, ticketID uint) (*response.TriageResponse, error) {
	args := m.Called(ctx, ticketID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*response.TriageResponse), args.Error(1)
}
