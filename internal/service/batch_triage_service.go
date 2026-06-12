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
	"support-ticket.com/internal/worker"
)

func (s *triageServiceImpl) ExecuteBatchTriage(ctx context.Context, ticketIDs []uint) (*response.BatchTriageResponse, error) {
	startTime := time.Now()

	// 1. Validate request parameters
	if err := s.validateBatchRequest(ctx, ticketIDs); err != nil {
		return nil, err
	}

	slog.InfoContext(ctx, "initiating batch AI triage",
		slog.Any("ticket_ids", ticketIDs),
		slog.Int("worker_pool_size", s.cfg.AIWorkerPoolSize),
	)

	tickets, err := s.ticketRepo.FindByIds(ctx, ticketIDs)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch tickets for batch triage", slog.Any("error", err))
		return nil, fmt.Errorf("failed to fetch tickets: %w", err)
	}

	now := time.Now()
	fetchedMap := make(map[uint]*model.Ticket)
	for i := range tickets {
		fetchedMap[tickets[i].ID] = &tickets[i]
	}

	var validTickets []model.Ticket
	var failedItems []response.BatchTriageFailedItem

	for _, id := range ticketIDs {
		t, exists := fetchedMap[id]
		if !exists {
			slog.WarnContext(ctx, "batch triage validation failed: ticket not found",
				slog.Uint64("ticket_id", uint64(id)),
			)
			failedItems = append(failedItems, response.BatchTriageFailedItem{
				TicketID: id,
				Reason:   errmsgs.ErrTicketNotFound.Message,
			})
			continue
		}

		if t.Status == model.StatusResolved || t.Status == model.StatusCancelled || t.Status == model.StatusClosed {
			slog.WarnContext(ctx, "batch triage validation failed: ticket residing in terminal status boundary",
				slog.Uint64("ticket_id", uint64(t.ID)),
				slog.String("status", string(t.Status)),
			)
			failedItems = append(failedItems, response.BatchTriageFailedItem{
				TicketID: id,
				Reason:   errmsgs.ErrTicketResolved.Message,
			})
			continue
		}

		if t.SLADueAt != nil && t.SLADueAt.Before(now) {
			slog.WarnContext(ctx, "batch triage validation failed: ticket is already overdue, skipping triage",
				slog.Uint64("ticket_id", uint64(t.ID)),
				slog.Time("sla_due_at", *t.SLADueAt),
			)
			failedItems = append(failedItems, response.BatchTriageFailedItem{
				TicketID: id,
				Reason:   errmsgs.ErrTicketOverdue.Message,
			})
			continue
		}

		if len(strings.TrimSpace(t.Description)) < 10 {
			slog.WarnContext(ctx, "batch triage validation failed: ticket description too short, skipping triage",
				slog.Uint64("ticket_id", uint64(t.ID)),
				slog.Int("description_length", len(strings.TrimSpace(t.Description))),
			)
			failedItems = append(failedItems, response.BatchTriageFailedItem{
				TicketID: id,
				Reason:   errmsgs.ErrTicketDescriptionTooShort.Message,
			})
			continue
		}

		validTickets = append(validTickets, *t)
	}

	var processedItems []response.BatchTriageResponseItem
	fallbackCount := 0

	if len(validTickets) > 0 {
		report := s.fetchDailyReport(now)

		results := worker.RunWithPoolSize(validTickets, s.cfg.AIWorkerPoolSize, func(t model.Ticket) *response.BatchTriageResponseItem {
			return s.triageSingleTicket(ctx, t, now, report)
		})

		for _, item := range results {
			if item != nil {
				processedItems = append(processedItems, *item)
				if item.FallbackUsed {
					fallbackCount++
				}
			}
		}
	}

	duration := time.Since(startTime)
	slog.InfoContext(ctx, "batch triage completed",
		slog.Int("total_requested", len(ticketIDs)),
		slog.Int("processed_count", len(processedItems)),
		slog.Int("failed_count", len(failedItems)),
		slog.Int("fallback_count", fallbackCount),
		slog.Duration("duration", duration),
	)

	return &response.BatchTriageResponse{
		Processed: processedItems,
		Failed:    failedItems,
	}, nil
}

func (s *triageServiceImpl) validateBatchRequest(ctx context.Context, ticketIDs []uint) error {
	if len(ticketIDs) == 0 {
		slog.WarnContext(ctx, "batch triage validation failed: empty ticket IDs array")
		return errmsgs.ErrEmptyBatch
	}

	if len(ticketIDs) > s.cfg.AIMaxBatchSize {
		slog.WarnContext(ctx, "batch triage validation failed: batch size exceeds maximum allowed",
			slog.Int("limit", s.cfg.AIMaxBatchSize),
			slog.Int("got", len(ticketIDs)),
		)
		return errmsgs.ErrBatchTooLarge
	}

	return nil
}

func (s *triageServiceImpl) fetchDailyReport(now time.Time) *model.TicketReport {
	report, err := s.reportRepo.GetByDate(now)
	if err != nil && strings.Contains(err.Error(), "report not found") {
		report, _ = s.reportRepo.GetByDate(now.Add(-24 * time.Hour))
	}
	return report
}

func (s *triageServiceImpl) triageSingleTicket(ctx context.Context, t model.Ticket, now time.Time, report *model.TicketReport) *response.BatchTriageResponseItem {
	slog.InfoContext(ctx, "worker processing AI triage", slog.Uint64("ticket_id", uint64(t.ID)))

	slaEvidence := "SLA not set."
	if t.SLADueAt != nil {
		timeLeft := t.SLADueAt.Sub(now).Round(time.Minute)
		if timeLeft < 0 {
			slaEvidence = fmt.Sprintf("CRITICAL: Ticket is already OVERDUE by %s", -timeLeft)
		} else {
			slaEvidence = fmt.Sprintf("Ticket has %s remaining before SLA breach", timeLeft)
		}
	}

	promptData := ai.TriagePromptData{
		Ticket:      t,
		Events:      t.Events,
		SLAPolicy:   "Max resolution time is determined by priority: High (4h), Medium (24h), Low (48h).",
		DailyReport: report,
		TimeLeft:    slaEvidence,
	}

	aiCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	aiResult, aiErr := s.aiAdapter.AnalyzeTicket(aiCtx, promptData)
	if aiErr != nil {
		slog.WarnContext(ctx, "AI adapter failed, evaluating fallback",
			slog.Uint64("ticket_id", uint64(t.ID)),
			slog.Any("ai_error", aiErr),
		)
	}

	finalResult := ai.ApplyFallbackIfNeeded(aiResult, aiErr, &t)

	dbResult := &model.AITicketTriageResult{
		TicketID:              t.ID,
		Category:              finalResult.Category,
		UrgencyLevel:          finalResult.UrgencyLevel,
		SLABreachRisk:         finalResult.SLABreachRisk,
		ReasonSummary:         finalResult.ReasonSummary,
		RecommendedNextAction: finalResult.RecommendedNextAction,
		ConfidenceScore:       finalResult.ConfidenceScore,
		FallbackUsed:          finalResult.FallbackUsed,
		PromptVersion:         finalResult.PromptVersion,
	}

	// Save to Database
	if err := s.triageRepo.Create(ctx, dbResult); err != nil {
		slog.ErrorContext(ctx, "failed to save triage result",
			slog.Uint64("ticket_id", uint64(t.ID)),
			slog.Any("db_error", err),
		)
	}

	slog.InfoContext(ctx, "worker triage task finished",
		slog.Uint64("ticket_id", uint64(t.ID)),
		slog.Bool("fallback_used", finalResult.FallbackUsed),
	)

	return &response.BatchTriageResponseItem{
		TicketID:              t.ID,
		Category:              finalResult.Category,
		UrgencyLevel:          finalResult.UrgencyLevel,
		SLABreachRisk:         finalResult.SLABreachRisk,
		ReasonSummary:         finalResult.ReasonSummary,
		RecommendedNextAction: finalResult.RecommendedNextAction,
		ConfidenceScore:       finalResult.ConfidenceScore,
		FallbackUsed:          finalResult.FallbackUsed,
		PromptVersion:         finalResult.PromptVersion,
	}
}
