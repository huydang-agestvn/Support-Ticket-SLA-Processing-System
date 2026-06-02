package service

import (
	"bytes"
	"fmt"
	"html/template"
	"log"
	"net/smtp"

	"support-ticket.com/internal/config"
	"support-ticket.com/internal/model"
)

type EmailService interface {
	SendDailyReportEmail(report *domain.TicketReport) error
}

type emailService struct {
	cfg *config.Config
}

func NewEmailService(cfg *config.Config) EmailService {
	return &emailService{cfg: cfg}
}

func (s *emailService) SendDailyReportEmail(report *domain.TicketReport) error {
	if s.cfg.SMTPHost == "" || s.cfg.SMTPUser == "" {
		return fmt.Errorf("SMTP configuration is incomplete, skipping email")
	}
	if s.cfg.ManagerEmail == "" {
		return fmt.Errorf("Manager email is empty, skipping email")
	}

	// Parse HTML template
	t, err := template.ParseFiles("internal/templates/daily_report.html")
	if err != nil {
		// Fallback to absolute path or other relative path in case running from different directory
		t, err = template.ParseFiles("../../internal/templates/daily_report.html")
		if err != nil {
			// One more fallback for binary running from root
			t, err = template.ParseFiles("templates/daily_report.html")
			if err != nil {
				return fmt.Errorf("failed to parse email template: %w", err)
			}
		}
	}

	// Execute template with data
	var body bytes.Buffer
	if err := t.Execute(&body, report); err != nil {
		return fmt.Errorf("failed to execute email template: %w", err)
	}

	// Prepare email message
	mimeHeaders := "MIME-version: 1.0;\nContent-Type: text/html; charset=\"UTF-8\";\n\n"
	subject := fmt.Sprintf("Subject: Daily SLA Report - %s\n", report.ReportDate.Format("2006-01-02"))
	msg := []byte(subject + mimeHeaders + body.String())

	// Authentication
	auth := smtp.PlainAuth("", s.cfg.SMTPUser, s.cfg.SMTPPass, s.cfg.SMTPHost)

	// SMTP connection
	addr := fmt.Sprintf("%s:%d", s.cfg.SMTPHost, s.cfg.SMTPPort)
	log.Printf("[EmailService] Sending daily report to %s...", s.cfg.ManagerEmail)
	err = smtp.SendMail(addr, auth, s.cfg.SMTPUser, []string{s.cfg.ManagerEmail}, msg)
	if err != nil {
		return fmt.Errorf("failed to send email: %w", err)
	}

	log.Printf("[EmailService] Daily report email successfully sent to %s", s.cfg.ManagerEmail)
	return nil
}
