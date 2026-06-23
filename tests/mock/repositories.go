package mock

import (
	"context"
	"time"

	"github.com/stretchr/testify/mock"
	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/model"
)

// MockTicketRepository
type MockTicketRepository struct {
	mock.Mock
}

func (m *MockTicketRepository) Create(ctx context.Context, ticket *model.Ticket) error {
	args := m.Called(ctx, ticket)
	return args.Error(0)
}

func (m *MockTicketRepository) FindById(ctx context.Context, id uint) (*model.Ticket, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.Ticket), args.Error(1)
}

func (m *MockTicketRepository) FindAll(ctx context.Context, filter request.TicketFilter, offset, limit int) ([]model.Ticket, int64, error) {
	args := m.Called(ctx, filter, offset, limit)
	if args.Get(0) == nil {
		return nil, args.Get(1).(int64), args.Error(2)
	}
	return args.Get(0).([]model.Ticket), args.Get(1).(int64), args.Error(2)
}

func (m *MockTicketRepository) UpdateStatusWithEvent(ctx context.Context, ticket *model.Ticket, event *model.TicketEvent) error {
	args := m.Called(ctx, ticket, event)
	return args.Error(0)
}

func (m *MockTicketRepository) GetExistingTicketIDs(ctx context.Context, ticketIDs []uint) (map[uint]bool, error) {
	args := m.Called(ctx, ticketIDs)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(map[uint]bool), args.Error(1)
}

func (m *MockTicketRepository) GetTicketStatusAndCreatedAt(ctx context.Context, ticketIDs []uint) (map[uint]model.TicketStatus, map[uint]time.Time, map[uint]string, error) {
	args := m.Called(ctx, ticketIDs)
	if args.Get(0) == nil {
		return nil, nil, nil, args.Error(3)
	}
	return args.Get(0).(map[uint]model.TicketStatus), args.Get(1).(map[uint]time.Time), args.Get(2).(map[uint]string), args.Error(3)
}

func (m *MockTicketRepository) Transaction(ctx context.Context, fn func(ctx context.Context) error) error {
	args := m.Called(ctx, fn)
	if err := args.Error(0); err != nil {
		return err
	}
	return fn(ctx)
}

func (m *MockTicketRepository) UpdateStatusesBatch(ctx context.Context, tickets []model.Ticket) error {
	args := m.Called(ctx, tickets)
	return args.Error(0)
}

func (m *MockTicketRepository) FindByIds(ctx context.Context, ids []uint) ([]model.Ticket, error) {
	args := m.Called(ctx, ids)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]model.Ticket), args.Error(1)
}

func (m *MockTicketRepository) UpdateCategory(ctx context.Context, id uint, category model.TicketCategory) error {
	args := m.Called(ctx, id, category)
	return args.Error(0)
}

// MockTicketEventRepository
type MockTicketEventRepository struct {
	mock.Mock
}

func (m *MockTicketEventRepository) CreateBatch(ctx context.Context, events []model.TicketEvent) error {
	args := m.Called(ctx, events)
	return args.Error(0)
}

func (m *MockTicketEventRepository) Create(ctx context.Context, event *model.TicketEvent) error {
	args := m.Called(ctx, event)
	return args.Error(0)
}

func (m *MockTicketEventRepository) GetExistingEventKeys(ctx context.Context, keys []string) (map[string]bool, error) {
	args := m.Called(ctx, keys)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(map[string]bool), args.Error(1)
}

func (m *MockTicketEventRepository) FetchLatestEventPerTicket(ctx context.Context, ticketIDs []int) ([]model.TicketEvent, error) {
	args := m.Called(ctx, ticketIDs)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]model.TicketEvent), args.Error(1)
}

func (m *MockTicketEventRepository) FetchLatestResolvedEventPerTicket(ctx context.Context, ticketIDs []int) ([]model.TicketEvent, error) {
	args := m.Called(ctx, ticketIDs)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]model.TicketEvent), args.Error(1)
}

// MockReportRepository
type MockReportRepository struct {
	mock.Mock
}

func (m *MockReportRepository) AggregateByDate(date time.Time) (*model.TicketReport, error) {
	args := m.Called(date)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.TicketReport), args.Error(1)
}

func (m *MockReportRepository) Upsert(report *model.TicketReport) error {
	args := m.Called(report)
	return args.Error(0)
}

func (m *MockReportRepository) GetByDate(date time.Time) (*model.TicketReport, error) {
	args := m.Called(date)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.TicketReport), args.Error(1)
}

// MockTriageRepository
type MockTriageRepository struct {
	mock.Mock
}

func (m *MockTriageRepository) Create(ctx context.Context, result *model.AITicketTriageResult) error {
	args := m.Called(ctx, result)
	return args.Error(0)
}

func (m *MockTriageRepository) FindLatestByTicketID(ctx context.Context, ticketID uint) (*model.AITicketTriageResult, error) {
	args := m.Called(ctx, ticketID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*model.AITicketTriageResult), args.Error(1)
}

func (m *MockTriageRepository) GetActiveRulePatterns(ctx context.Context) ([]response.RulePatternResponse, error) {
	args := m.Called(ctx)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]response.RulePatternResponse), args.Error(1)
}

// MockEvaluationRepository
type MockEvaluationRepository struct {
	mock.Mock
}

func (m *MockEvaluationRepository) GetCases(ctx context.Context, caseIDs []uint) ([]model.AIEvaluationCase, error) {
	args := m.Called(ctx, caseIDs)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]model.AIEvaluationCase), args.Error(1)
}

func (m *MockEvaluationRepository) CreateRun(ctx context.Context, run *model.AIEvaluationRun) error {
	args := m.Called(ctx, run)
	return args.Error(0)
}

// MockTriageAdapter
type MockTriageAdapter struct {
	mock.Mock
}

func (m *MockTriageAdapter) AnalyzeTicket(ctx context.Context, data ai.TriagePromptData) (*ai.TriageResult, error) {
	args := m.Called(ctx, data)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*ai.TriageResult), args.Error(1)
}

func (m *MockTriageAdapter) AnalyzeTicketWithVersion(ctx context.Context, data ai.TriagePromptData, promptVersion string) (*ai.TriageResult, error) {
	args := m.Called(ctx, data, promptVersion)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*ai.TriageResult), args.Error(1)
}

func (m *MockTriageAdapter) Model() string {
	args := m.Called()
	return args.String(0)
}
