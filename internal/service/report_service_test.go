package service

import (
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	domain "support-ticket.com/internal/model"
)

// MockReportRepository is a mock of ReportRepository
type MockReportRepository struct {
	mock.Mock
}

func (m *MockReportRepository) AggregateByDate(date time.Time) (*domain.TicketReport, error) {
	args := m.Called(date)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.TicketReport), args.Error(1)
}

func (m *MockReportRepository) Upsert(report *domain.TicketReport) error {
	args := m.Called(report)
	return args.Error(0)
}

func (m *MockReportRepository) GetByDate(date time.Time) (*domain.TicketReport, error) {
	args := m.Called(date)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.TicketReport), args.Error(1)
}

func TestGenerateReport(t *testing.T) {
	now := time.Now()

	t.Run("Success", func(t *testing.T) {
		mockRepo := new(MockReportRepository)
		svc := NewReportService(mockRepo)
		report := &domain.TicketReport{ReportDate: now}
		mockRepo.On("AggregateByDate", now).Return(report, nil)
		mockRepo.On("Upsert", report).Return(nil)

		res, err := svc.GenerateReport(now)

		assert.NoError(t, err)
		assert.Equal(t, report, res)
		mockRepo.AssertExpectations(t)
	})

	t.Run("AggregateError", func(t *testing.T) {
		mockRepo := new(MockReportRepository)
		svc := NewReportService(mockRepo)
		mockRepo.On("AggregateByDate", now).Return(nil, errors.New("db error"))

		res, err := svc.GenerateReport(now)

		assert.Error(t, err)
		assert.Nil(t, res)
		if err != nil {
			assert.Contains(t, err.Error(), "aggregate report")
		}
	})

	t.Run("UpsertError", func(t *testing.T) {
		mockRepo := new(MockReportRepository)
		svc := NewReportService(mockRepo)
		report := &domain.TicketReport{ReportDate: now}
		mockRepo.On("AggregateByDate", now).Return(report, nil)
		mockRepo.On("Upsert", report).Return(errors.New("db error"))

		res, err := svc.GenerateReport(now)

		assert.Error(t, err)
		assert.Nil(t, res)
		if err != nil {
			assert.Contains(t, err.Error(), "save report")
		}
	})
}

func TestGetReport(t *testing.T) {
	now := time.Now()

	t.Run("Success", func(t *testing.T) {
		mockRepo := new(MockReportRepository)
		svc := NewReportService(mockRepo)
		report := &domain.TicketReport{ReportDate: now}
		mockRepo.On("GetByDate", now).Return(report, nil)

		res, err := svc.GetReport(now)

		assert.NoError(t, err)
		assert.Equal(t, report, res)
		mockRepo.AssertExpectations(t)
	})

	t.Run("Error", func(t *testing.T) {
		mockRepo := new(MockReportRepository)
		svc := NewReportService(mockRepo)
		mockRepo.On("GetByDate", now).Return(nil, errors.New("not found"))

		res, err := svc.GetReport(now)

		assert.Error(t, err)
		assert.Nil(t, res)
	})
}

