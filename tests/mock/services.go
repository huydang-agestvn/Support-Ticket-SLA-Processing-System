package mock

import (
	"context"
	"time"

	"github.com/stretchr/testify/mock"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
	domain "support-ticket.com/internal/model"
)

// MockReportService
type MockReportService struct {
	mock.Mock
}

func (m *MockReportService) GenerateReport(date time.Time) (*domain.TicketReport, error) {
	args := m.Called(date)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.TicketReport), args.Error(1)
}

func (m *MockReportService) GetReport(date time.Time) (*domain.TicketReport, error) {
	args := m.Called(date)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.TicketReport), args.Error(1)
}

// MockTicketService
type MockTicketService struct {
	mock.Mock
}

func (m *MockTicketService) Create(ctx context.Context, req request.CreateTicketReq) (*domain.Ticket, error) {
	args := m.Called(ctx, req)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.Ticket), args.Error(1)
}

func (m *MockTicketService) FindById(ctx context.Context, id uint) (*domain.Ticket, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.Ticket), args.Error(1)
}

func (m *MockTicketService) FindAll(ctx context.Context, filter request.TicketFilter, paging common.PaginationQuery) (*common.PaginatedResult[domain.Ticket], error) {
	args := m.Called(ctx, filter, paging)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*common.PaginatedResult[domain.Ticket]), args.Error(1)
}

func (m *MockTicketService) UpdateTicketStatus(ctx context.Context, id uint, req request.UpdateStatusReq) error {
	args := m.Called(ctx, id, req)
	return args.Error(0)
}

// MockTicketEventService
type MockTicketEventService struct {
	mock.Mock
}

func (m *MockTicketEventService) Import(ctx context.Context, events []domain.TicketEvent) (domain.BatchImportResult, error) {
	args := m.Called(ctx, events)
	return args.Get(0).(domain.BatchImportResult), args.Error(1)
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
