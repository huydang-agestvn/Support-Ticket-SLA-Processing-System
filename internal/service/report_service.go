package service

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"support-ticket.com/internal/model"
	"support-ticket.com/internal/repository"
)

type ReportService interface {
	GenerateReport(date time.Time) (*model.TicketReport, error)
	GetReport(date time.Time) (*model.TicketReport, error)
}

type reportService struct {
	repo repository.ReportRepository
}

func NewReportService(repo repository.ReportRepository) ReportService {
	return &reportService{repo: repo}
}

func (s *reportService) GenerateReport(date time.Time) (*model.TicketReport, error) {
	report, err := s.repo.AggregateByDate(date)
	if err != nil {
		slog.ErrorContext(context.Background(), "failed to aggregate report",
			slog.Time("date", date),
			slog.Any("db_error", err),
		)
		return nil, fmt.Errorf("aggregate report: %w", err)
	}

	if err := report.Validate(); err != nil {
		slog.ErrorContext(context.Background(), "generated report validation failed",
			slog.Time("date", date),
			slog.Any("validation_error", err),
		)
		return nil, fmt.Errorf("invalid report data: %w", err)
	}

	if err := s.repo.Upsert(report); err != nil {
		slog.ErrorContext(context.Background(), "failed to save report",
			slog.Time("date", date),
			slog.Any("db_error", err),
		)
		return nil, fmt.Errorf("save report: %w", err)
	}

	slog.InfoContext(context.Background(), "report generated and saved successfully",
		slog.Time("date", date),
	)

	return report, nil
}

func (s *reportService) GetReport(date time.Time) (*model.TicketReport, error) {
	return s.repo.GetByDate(date)
}
