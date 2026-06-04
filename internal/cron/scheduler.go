package cron

import (
	"context"
	"log"
	"log/slog"
	"time"

	"github.com/robfig/cron/v3"
	"support-ticket.com/internal/service"
)

type Scheduler struct {
	cron      *cron.Cron
	reportSvc service.ReportService
	emailSvc  service.EmailService
}

func NewScheduler(reportSvc service.ReportService, emailSvc service.EmailService) *Scheduler {
	c := cron.New(cron.WithLocation(time.Local))
	return &Scheduler{
		cron:      c,
		reportSvc: reportSvc,
		emailSvc:  emailSvc,
	}
}

// Start registers and starts the cron jobs.
func (s *Scheduler) Start() error {
	_, err := s.cron.AddFunc("0 17 * * *", func() {
		now := time.Now()
		slog.InfoContext(context.Background(), "Starting daily ticket report aggregation for %s...", slog.String("date", now.Format("2006-01-02")))

		report, err := s.reportSvc.GenerateReport(now)
		if err != nil {
			slog.ErrorContext(context.Background(), "Error generating report", slog.Any("error", err))
			return
		}

		slog.InfoContext(context.Background(), "Daily report successfully generated", slog.String("report_date", report.ReportDate.Format("2006-01-02")), slog.Int("report_id", int(report.ID)))

		// Send email to manager
		if s.emailSvc != nil {
			if err := s.emailSvc.SendDailyReportEmail(report); err != nil {
				log.Printf("[Cron] Error sending daily report email: %v", err)
			}
		}
	})
	if err != nil {
		return err
	}

	s.cron.Start()
	slog.InfoContext(context.Background(), "Scheduler started successfully. Daily report job registered for 5:00 PM.")
	return nil
}

// Stop gracefully shuts down the cron scheduler.
func (s *Scheduler) Stop() {
	s.cron.Stop()
}

// GetCron returns the underlying cron instance.
func (s *Scheduler) GetCron() *cron.Cron {
	return s.cron
}

// GetReportService returns the underlying report service.
func (s *Scheduler) GetReportService() service.ReportService {
	return s.reportSvc
}
