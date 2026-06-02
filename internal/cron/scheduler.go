package cron

import (
	"log"
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
	_, err := s.cron.AddFunc("06 14 * * *", func() {
		now := time.Now()
		log.Printf("[Cron] Starting daily ticket report aggregation for %s...", now.Format("2006-01-02"))
		
		report, err := s.reportSvc.GenerateReport(now)
		if err != nil {
			log.Printf("[Cron] Error generating report: %v", err)
			return
		}
		
		log.Printf("[Cron] Daily report successfully generated for %s (ID: %d)", report.ReportDate.Format("2006-01-02"), report.ID)

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
	log.Println("[Cron] Scheduler started successfully. Daily report job registered for 5:00 PM.")
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

