package service

import (
	"fmt"
	"time"

	"support-ticket.com/internal/model"
	"support-ticket.com/internal/repository"
)

type ReportService interface {
	GenerateReport(date time.Time) (*domain.TicketReport, error)
	GetReport(date time.Time) (*domain.TicketReport, error)
}

type reportService struct {
	repo repository.ReportRepository
}

func NewReportService(repo repository.ReportRepository) ReportService {
	return &reportService{repo: repo}
}

func (s *reportService) GenerateReport(date time.Time) (*domain.TicketReport, error) {
	report, err := s.repo.AggregateByDate(date)
	if err != nil {
		return nil, fmt.Errorf("aggregate report: %w", err)
	}

	if err := report.Validate(); err != nil {
		return nil, fmt.Errorf("invalid report data: %w", err)
	}

	if err := s.repo.Upsert(report); err != nil {
		return nil, fmt.Errorf("save report: %w", err)
	}

	return report, nil
}

func (s *reportService) GetReport(date time.Time) (*domain.TicketReport, error) {
	report, err := s.repo.GetByDate(date)
	if err != nil {
		// Auto-generate report real-time if not cached in DB
		generatedReport, genErr := s.GenerateReport(date)
		if genErr != nil {
			return nil, fmt.Errorf("auto-generate report: %w", genErr)
		}
		return generatedReport, nil
	}
	return report, nil
}
