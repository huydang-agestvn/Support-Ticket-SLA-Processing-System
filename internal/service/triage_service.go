package service

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/errmsgs"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/repository"
)

type TriageService interface {
	ExecuteTriage(ctx context.Context, ticketID uint) (*response.TriageResponse, error)
}

type triageServiceImpl struct {
	ticketRepo repository.TicketRepository
	reportRepo repository.ReportRepository
	triageRepo repository.TriageRepository
	aiAdapter  ai.TriageAdapter
}

func NewTriageService(
	ticketRepo repository.TicketRepository,
	reportRepo repository.ReportRepository,
	triageRepo repository.TriageRepository,
	aiAdapter ai.TriageAdapter,
) TriageService {
	return &triageServiceImpl{
		ticketRepo: ticketRepo,
		reportRepo: reportRepo,
		triageRepo: triageRepo,
		aiAdapter:  aiAdapter,
	}
}

func (s *triageServiceImpl) buildTriageContext(ctx context.Context, ticketID uint) (*model.Ticket, ai.TriagePromptData, error) {
	ticket, err := s.ticketRepo.FindById(ctx, ticketID)
	if err != nil {
		return nil, ai.TriagePromptData{}, fmt.Errorf("failed to fetch ticket details: %w", err)
	}
	if ticket == nil {
		return nil, ai.TriagePromptData{}, errmsgs.ErrTicketNotFound
	}

	now := time.Now()
	report, err := s.reportRepo.GetByDate(now)
	if err != nil && strings.Contains(err.Error(), "report not found") {
		report, _ = s.reportRepo.GetByDate(now.Add(-24 * time.Hour))
	}

	dailyStats := "No recent SLA stats available in the system."
	if report != nil {
		dailyStats = fmt.Sprintf("Daily Report (%s) - Avg Resolution Time: %.1fh, Overdue Tickets: %d, SLA Breaches: %d",
			report.ReportDate.Format("2006-01-02"), report.AvgResolutionTime, report.OverdueCount, report.SlaBreacheCount)
	}

	promptData := ai.TriagePromptData{
		Ticket:     *ticket,
		Events:     ticket.Events,
		SLAPolicy:  "Max resolution time is determined by priority: High (4h), Medium (24h), Low (48h).",
		DailyStats: dailyStats,
	}

	return ticket, promptData, nil
}

func (s *triageServiceImpl) ExecuteTriage(ctx context.Context, ticketID uint) (*response.TriageResponse, error) {
	slog.InfoContext(ctx, "initiating AI triage", slog.Uint64("ticket_id", uint64(ticketID)))

	ticket, promptData, err := s.buildTriageContext(ctx, ticketID)
	if err != nil {
		return nil, err
	}

	aiCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	aiResult, aiErr := s.aiAdapter.AnalyzeTicket(aiCtx, promptData)
	if aiErr != nil {
		slog.WarnContext(ctx, "AI adapter failed, evaluating fallback",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.Any("ai_error", aiErr),
		)
	}

	finalResult := ai.ApplyFallbackIfNeeded(aiResult, aiErr, ticket)

	dbResult := &model.AITicketTriageResult{
		TicketID:              ticket.ID,
		Category:              finalResult.Category,
		UrgencyLevel:          finalResult.UrgencyLevel,
		SLABreachRisk:         finalResult.SLABreachRisk,
		ReasonSummary:         finalResult.ReasonSummary,
		RecommendedNextAction: finalResult.RecommendedNextAction,
		ConfidenceScore:       finalResult.ConfidenceScore,
		FallbackUsed:          finalResult.FallbackUsed,
		PromptVersion:         finalResult.PromptVersion,
	}

	if err := s.triageRepo.Create(ctx, dbResult); err != nil {
		slog.ErrorContext(ctx, "failed to save triage result",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.Any("db_error", err),
		)
		return nil, fmt.Errorf("failed to save triage result: %w", err)
	}

	slog.InfoContext(ctx, "triage completed successfully",
		slog.Uint64("ticket_id", uint64(ticketID)),
		slog.Bool("fallback_used", finalResult.FallbackUsed),
	)

	apiResponse := &response.TriageResponse{
		Category:              finalResult.Category,
		UrgencyLevel:          finalResult.UrgencyLevel,
		SLABreachRisk:         finalResult.SLABreachRisk,
		ReasonSummary:         finalResult.ReasonSummary,
		RecommendedNextAction: finalResult.RecommendedNextAction,
		ConfidenceScore:       finalResult.ConfidenceScore,
		FallbackUsed:          finalResult.FallbackUsed,
		PromptVersion:         finalResult.PromptVersion,
	}

	return apiResponse, nil
}
