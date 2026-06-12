package service

import (
	"bytes"
	"context"
	"fmt"
	"html/template"
	"log/slog"
	"net/smtp"

	"support-ticket.com/internal/config"
	"support-ticket.com/internal/model"
)

type EmailService interface {
	SendDailyReportEmail(report *model.TicketReport) error
}

type emailService struct {
	cfg *config.Config
}

func NewEmailService(cfg *config.Config) EmailService {
	return &emailService{cfg: cfg}
}

func (s *emailService) SendDailyReportEmail(report *model.TicketReport) error {
	if s.cfg.SMTPHost == "" || s.cfg.SMTPUser == "" {
		return fmt.Errorf("SMTP configuration is incomplete, skipping email")
	}
	if s.cfg.ManagerEmail == "" {
		return fmt.Errorf("Manager email is empty, skipping email")
	}

	t, err := template.ParseFiles("internal/templates/daily_report.html")
	if err != nil {
		t, err = template.ParseFiles("../../internal/templates/daily_report.html")
		if err != nil {
			t, err = template.ParseFiles("templates/daily_report.html")
			if err != nil {
				return fmt.Errorf("failed to parse email template: %w", err)
			}
		}
	}

	var body bytes.Buffer
	if err := t.Execute(&body, report); err != nil {
		return fmt.Errorf("failed to execute email template: %w", err)
	}

	mimeHeaders := "MIME-version: 1.0;\nContent-Type: text/html; charset=\"UTF-8\";\n\n"
	subject := fmt.Sprintf("Subject: Daily SLA Report - %s\n", report.ReportDate.Format("2006-01-02"))
	msg := []byte(subject + mimeHeaders + body.String())

	auth := smtp.PlainAuth("", s.cfg.SMTPUser, s.cfg.SMTPPass, s.cfg.SMTPHost)

	addr := fmt.Sprintf("%s:%d", s.cfg.SMTPHost, s.cfg.SMTPPort)
	
	slog.InfoContext(context.Background(), "sending daily report",
		slog.String("manager_email", s.cfg.ManagerEmail),
	)
	
	err = smtp.SendMail(addr, auth, s.cfg.SMTPUser, []string{s.cfg.ManagerEmail}, msg)
	if err != nil {
		slog.ErrorContext(context.Background(), "failed to send email",
			slog.String("manager_email", s.cfg.ManagerEmail),
			slog.Any("error", err),
		)
		return fmt.Errorf("failed to send email: %w", err)
	}

	slog.InfoContext(context.Background(), "daily report email successfully sent",
		slog.String("manager_email", s.cfg.ManagerEmail),
	)
	return nil
}
