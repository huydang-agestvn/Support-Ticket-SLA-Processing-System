package service

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/errmsgs"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/repository"
)

type TriageService interface {
	ExecuteTriage(ctx context.Context, ticketID uint) (*response.TriageResponse, error)
	GetLatestTriageResult(ctx context.Context, ticketID uint) (*response.TriageResponse, error)
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

	// Business Validations for AI Triage
	// 1. Do not triage tickets that are already in a terminal state
	if ticket.Status == model.StatusResolved || ticket.Status == model.StatusClosed || ticket.Status == model.StatusCancelled {
		slog.WarnContext(ctx, "ticket is in terminal state, skipping triage",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.String("status", string(ticket.Status)),
		)
		return nil, ai.TriagePromptData{}, common.NewBadRequest(
			common.ErrCodeInvalidInput,
			fmt.Sprintf("ticket is already %s and does not require AI triage", ticket.Status),
		)
	}

	// 2. Do not triage tickets that are already overdue
	if ticket.SLADueAt != nil && ticket.SLADueAt.Before(now) {
		slog.WarnContext(ctx, "ticket is already overdue, skipping triage",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.Time("sla_due_at", *ticket.SLADueAt),
		)
		return nil, ai.TriagePromptData{}, common.NewBadRequest(
			common.ErrCodeInvalidInput,
			"ticket is already overdue and requires immediate manual intervention",
		)
	}

	// 3. Ensure ticket description is meaningful (preventing "garbage" inputs to AI)
	if len(strings.TrimSpace(ticket.Description)) < 10 {
		slog.WarnContext(ctx, "ticket description too short, skipping triage",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.Int("description_length", len(strings.TrimSpace(ticket.Description))),
		)
		return nil, ai.TriagePromptData{}, common.NewBadRequest(
			common.ErrCodeInvalidInput,
			"ticket description is too short for meaningful AI triage (minimum 10 characters required)",
		)
	}

	report, err := s.reportRepo.GetByDate(now)
	if err != nil && strings.Contains(err.Error(), "report not found") {
		report, _ = s.reportRepo.GetByDate(now.Add(-24 * time.Hour))
	}

	slaEvidence := "SLA not set."
	if ticket.SLADueAt != nil {
		timeLeft := ticket.SLADueAt.Sub(now).Round(time.Minute)
		slaEvidence = fmt.Sprintf("Ticket has %s remaining before SLA breach", timeLeft)
	}

	promptData := ai.TriagePromptData{
		Ticket:      *ticket,
		Events:      ticket.Events,
		SLAPolicy:   "Max resolution time is determined by priority: High (4h), Medium (24h), Low (48h).",
		DailyReport: report,
		TimeLeft:    slaEvidence,
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
	} else if aiResult != nil && aiResult.ConfidenceScore < 0.5 {
		slog.WarnContext(ctx, "AI returned low confidence, fallback will be triggered",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.Float64("confidence_score", aiResult.ConfidenceScore),
			slog.String("ai_category", aiResult.Category),
			slog.String("ai_reason", aiResult.ReasonSummary),
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

func (s *triageServiceImpl) GetLatestTriageResult(ctx context.Context, ticketID uint) (*response.TriageResponse, error) {
	slog.InfoContext(ctx, "fetching latest triage result", slog.Uint64("ticket_id", uint64(ticketID)))

	// Xác minh ticket tồn tại
	ticket, err := s.ticketRepo.FindById(ctx, ticketID)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch ticket",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.Any("error", err),
		)
		return nil, fmt.Errorf("failed to fetch ticket: %w", err)
	}
	if ticket == nil {
		return nil, errmsgs.ErrTicketNotFound
	}

	dbResult, err := s.triageRepo.FindLatestByTicketID(ctx, ticketID)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch latest triage result",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.Any("error", err),
		)
		return nil, fmt.Errorf("failed to fetch latest triage result: %w", err)
	}
	if dbResult == nil {
		return nil, errmsgs.ErrTriageNotFound
	}

	slog.InfoContext(ctx, "latest triage result fetched successfully", slog.Uint64("ticket_id", uint64(ticketID)))

	return &response.TriageResponse{
		Category:              dbResult.Category,
		UrgencyLevel:          dbResult.UrgencyLevel,
		SLABreachRisk:         dbResult.SLABreachRisk,
		ReasonSummary:         dbResult.ReasonSummary,
		RecommendedNextAction: dbResult.RecommendedNextAction,
		ConfidenceScore:       dbResult.ConfidenceScore,
		FallbackUsed:          dbResult.FallbackUsed,
		PromptVersion:         dbResult.PromptVersion,
	}, nil
}
