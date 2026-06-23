package service

import (
	"context"
	"fmt"
	"log/slog"
	"regexp"
	"strings"
	"time"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/config"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/errmsgs"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/repository"
)

type TriageService interface {
	ExecuteTriage(ctx context.Context, ticketID uint) (*response.TriageResponse, error)
	GetLatestTriageResult(ctx context.Context, ticketID uint) (*response.TriageResponse, error)
	ExecuteBatchTriage(ctx context.Context, ticketIDs []uint) (*response.BatchTriageResponse, error)
}

type triageServiceImpl struct {
	ticketRepo      repository.TicketRepository
	reportRepo      repository.ReportRepository
	triageRepo      repository.TriageRepository
	kbRepo          repository.KnowledgeBaseRepository
	aiAdapter       ai.TriageAdapter
	embeddingClient *ai.EmbeddingClient
	cfg             *config.Config
	contentSafety   ContentSafetyService
}

func NewTriageService(
	ticketRepo repository.TicketRepository,
	reportRepo repository.ReportRepository,
	triageRepo repository.TriageRepository,
	kbRepo repository.KnowledgeBaseRepository,
	aiAdapter ai.TriageAdapter,
	embeddingClient *ai.EmbeddingClient,
	cfg *config.Config,
) TriageService {
	return &triageServiceImpl{
		ticketRepo:      ticketRepo,
		reportRepo:      reportRepo,
		triageRepo:      triageRepo,
		kbRepo:          kbRepo,
		aiAdapter:       aiAdapter,
		embeddingClient: embeddingClient,
		cfg:             cfg,
		contentSafety:   NewContentSafetyService(),
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

	if err := s.ensureTicketContentSafe(ctx, ticket); err != nil {
		return nil, ai.TriagePromptData{}, err
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
		SLAPolicy:   ai.DefaultSLAPolicy,
		DailyReport: report,
		TimeLeft:    slaEvidence,
	}

	return ticket, promptData, nil
}

// buildRAGContext calls the embedding microservice and queries the Vector DB
// to retrieve the most semantically similar department descriptions and sample tickets.
// Returns a formatted context string to inject into the AI prompt.
func (s *triageServiceImpl) buildRAGContext(ctx context.Context, title, description string) string {
	if s.embeddingClient == nil || s.kbRepo == nil {
		return ""
	}

	// 1. Field Selector: normalize ticket text
	normalizedText := ai.NormalizeTicketForEmbedding(title, description)

	// 2. Generate embedding vector via Ollama
	vec, err := s.embeddingClient.GetEmbedding(ctx, normalizedText)
	if err != nil {
		slog.WarnContext(ctx, "RAG: failed to get embedding, skipping context enrichment", slog.Any("error", err))
		return ""
	}

	// 3. Vector search: retrieve top-5 semantically similar entries
	matches, err := s.kbRepo.SearchSimilarContext(ctx, vec, 5)
	if err != nil {
		slog.WarnContext(ctx, "RAG: vector search failed, skipping context enrichment", slog.Any("error", err))
		return ""
	}

	if len(matches) == 0 {
		return ""
	}

	// 4. Format retrieved context for the prompt
	var sb strings.Builder
	sb.WriteString("# Relevant Knowledge Base Context (from Vector DB)\n")
	for i, m := range matches {
		sb.WriteString(fmt.Sprintf("%d. [%s | dept: %s] %s\n", i+1, m.SourceType, m.SubDepartmentCode, m.ContentText))
	}
	slog.InfoContext(ctx, "RAG: retrieved context", slog.Int("matches", len(matches)))
	return sb.String()
}

func (s *triageServiceImpl) ensureTicketContentSafe(ctx context.Context, ticket *model.Ticket) error {
	if s.contentSafety == nil {
		return nil
	}

	result := s.contentSafety.CheckTicket(ticket.Title, ticket.Description)
	if !result.Blocked {
		return nil
	}

	logBlockedTicket(ctx, ticket.ID, ticket.RequestorID, result, "single_triage")
	return contentSafetyBlockedError(result)
}

func logBlockedTicket(ctx context.Context, ticketID uint, userID string, result ContentSafetyResult, action string) {
	slog.WarnContext(ctx, "ticket blocked by content safety filter",
		slog.String("action", action),
		slog.String("request_id", requestIDFromContext(ctx)),
		slog.Uint64("ticket_id", uint64(ticketID)),
		slog.String("user_id", userID),
		slog.String("category", result.Category),
		slog.String("matched_rule", result.MatchedRule),
		slog.Time("timestamp", time.Now()),
	)
}

func contentSafetyBlockedError(result ContentSafetyResult) *common.Error {
	return common.NewBadRequest(
		common.ErrCodeTicketContentBlocked,
		fmt.Sprintf("ticket content blocked by safety filter: %s", result.Category),
	)
}

func requestIDFromContext(ctx context.Context) string {
	for _, key := range []any{"request_id", "requestID", "x-request-id"} {
		if value, ok := ctx.Value(key).(string); ok {
			return value
		}
	}
	return ""
}

func (s *triageServiceImpl) ExecuteTriage(ctx context.Context, ticketID uint) (*response.TriageResponse, error) {
	slog.InfoContext(ctx, "initiating AI triage", slog.Uint64("ticket_id", uint64(ticketID)))

	ticket, promptData, err := s.buildTriageContext(ctx, ticketID)
	if err != nil {
		return nil, err
	}

	// Layer 1: Content Safety Filter — handled inside buildTriageContext() above
	// (blocks profanity, spam, gibberish before any processing)

	// Layer 2: Rule Engine — short-circuit for high-confidence keyword/regex matches
	if ruleResult, matched, correctedCategory := s.evaluateUrgencyRuleEngine(ctx, ticket.Title, ticket.Description, string(ticket.Category), ticket.SLADueAt); matched {
		if correctedCategory != string(ticket.Category) {
			slog.WarnContext(ctx, "Urgency Level Rule Engine detected a critical input mismatch",
				slog.Uint64("ticket_id", uint64(ticketID)),
				slog.String("user_category", string(ticket.Category)),
				slog.String("corrected_category", correctedCategory),
				slog.String("urgency_level", ruleResult.UrgencyLevel),
				slog.String("sla_breach_risk", ruleResult.SLABreachRisk),
			)

			// Asynchronously update ticket category in database
			go func(tID uint, cat string) {
				bgCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				defer cancel()
				if err := s.ticketRepo.UpdateCategory(bgCtx, tID, model.TicketCategory(cat)); err != nil {
					slog.Error("failed to asynchronously update ticket category in DB",
						slog.Uint64("ticket_id", uint64(tID)),
						slog.String("category", cat),
						slog.Any("error", err),
					)
				} else {
					slog.Info("asynchronously updated ticket category in DB successfully",
						slog.Uint64("ticket_id", uint64(tID)),
						slog.String("category", cat),
					)
				}
			}(ticketID, correctedCategory)
		} else {
			slog.InfoContext(ctx, "Urgency Level Rule Engine short-circuit triggered",
				slog.Uint64("ticket_id", uint64(ticketID)),
				slog.String("category", string(ticket.Category)),
				slog.String("urgency_level", ruleResult.UrgencyLevel),
				slog.String("sla_breach_risk", ruleResult.SLABreachRisk),
			)
		}

		dbResult := &model.AITicketTriageResult{
			TicketID:              ticket.ID,
			Category:              ruleResult.Category,
			UrgencyLevel:          ruleResult.UrgencyLevel,
			SLABreachRisk:         ruleResult.SLABreachRisk,
			ReasonSummary:         ruleResult.ReasonSummary,
			RecommendedNextAction: ruleResult.RecommendedNextAction,
			ConfidenceScore:       ruleResult.ConfidenceScore,
			FallbackUsed:          ruleResult.FallbackUsed,
			PromptVersion:         ruleResult.PromptVersion,
		}

		if err := s.triageRepo.Create(ctx, dbResult); err != nil {
			slog.ErrorContext(ctx, "failed to save triage result from rule engine",
				slog.Uint64("ticket_id", uint64(ticketID)),
				slog.Any("db_error", err),
			)
			return nil, fmt.Errorf("failed to save triage result: %w", err)
		}

		return ruleResult, nil
	}

	// Layer 3: Field Selector + RAG Retrieval — normalize text, generate embedding,
	// query Vector DB for semantically similar departments and sample tickets
	ragContext := s.buildRAGContext(ctx, ticket.Title, ticket.Description)
	promptData.KnowledgeContext = ragContext

	// Layer 4: AI Classification — send enriched prompt to LLM via Fallback Chain
	timeoutSecs := 15
	if s.cfg != nil && s.cfg.AITimeoutSecs > 0 {
		timeoutSecs = s.cfg.AITimeoutSecs
	}
	aiCtx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSecs)*time.Second)
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

	// Layer 5: Save result + return response
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

func (s *triageServiceImpl) evaluateUrgencyRuleEngine(ctx context.Context, title, description string, originalCategory string, slaDueAt *time.Time) (*response.TriageResponse, bool, string) {
	// Fetch active rule patterns from database
	patterns, err := s.triageRepo.GetActiveRulePatterns(ctx)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch active rule patterns from database", slog.Any("error", err))
		return nil, false, ""
	}

	combined := fmt.Sprintf("%s\n%s", title, description)
	combinedLower := strings.ToLower(combined)

	// Helper function to match a pattern
	matchesPattern := func(p response.RulePatternResponse) bool {
		if p.PatternType == "regex" {
			re, err := regexp.Compile(p.Pattern)
			if err != nil {
				slog.WarnContext(ctx, "invalid rule pattern regex", slog.String("pattern", p.Pattern), slog.Any("error", err))
				return false
			}
			return re.MatchString(combined)
		}
		// Default to case-insensitive keyword match
		return strings.Contains(combinedLower, strings.ToLower(p.Pattern))
	}

	// 1. Priority 1: Check original input category first
	for _, p := range patterns {
		var cat string
		if len(p.SubDepartmentCode) >= 2 {
			cat = ai.MapDeptCodeToCategory(p.SubDepartmentCode[:2])
		}

		if cat != originalCategory {
			continue
		}

		if matchesPattern(p) {
			slaBreachRisk, reasonSummary, recommendedNextAction := s.calculateRuleEngineSLARisk(slaDueAt, false, originalCategory, originalCategory, p)
			return &response.TriageResponse{
				Category:              originalCategory,
				UrgencyLevel:          string(p.Priority),
				SLABreachRisk:         slaBreachRisk,
				ReasonSummary:         reasonSummary,
				RecommendedNextAction: recommendedNextAction,
				ConfidenceScore:       1.0,
				FallbackUsed:          false,
				PromptVersion:         ai.RuleEnginePromptVersion,
			}, true, originalCategory
		}
	}

	// 2. Priority 2: Check other categories
	for _, p := range patterns {
		var cat string
		if len(p.SubDepartmentCode) >= 2 {
			cat = ai.MapDeptCodeToCategory(p.SubDepartmentCode[:2])
		}

		if cat == originalCategory {
			continue
		}

		if matchesPattern(p) {
			correctedCategory := cat
			slaBreachRisk, reasonSummary, recommendedNextAction := s.calculateRuleEngineSLARisk(slaDueAt, true, originalCategory, correctedCategory, p)
			return &response.TriageResponse{
				Category:              correctedCategory,
				UrgencyLevel:          string(p.Priority),
				SLABreachRisk:         slaBreachRisk,
				ReasonSummary:         reasonSummary,
				RecommendedNextAction: recommendedNextAction,
				ConfidenceScore:       1.0,
				FallbackUsed:          false,
				PromptVersion:         ai.RuleEnginePromptVersion,
			}, true, correctedCategory
		}
	}

	return nil, false, ""
}

func (s *triageServiceImpl) calculateRuleEngineSLARisk(
	slaDueAt *time.Time,
	isMismatch bool,
	originalCategory,
	correctedCategory string,
	p response.RulePatternResponse,
) (string, string, string) {
	slaBreachRisk := "low"
	var reasonDurationInfo string

	if slaDueAt != nil {
		now := time.Now()
		if now.After(*slaDueAt) {
			slaBreachRisk = "overdue"
			reasonDurationInfo = fmt.Sprintf("SLA is overdue by %s, requiring immediate escalation", now.Sub(*slaDueAt).Round(time.Minute).String())
		} else {
			timeLeft := slaDueAt.Sub(now)
			if timeLeft <= 2*time.Hour {
				slaBreachRisk = "high"
				reasonDurationInfo = fmt.Sprintf("there are only %s left before SLA breach, leaving very little room for delay", timeLeft.Round(time.Minute).String())
			} else if timeLeft <= 24*time.Hour {
				slaBreachRisk = "medium"
				reasonDurationInfo = fmt.Sprintf("there are only %s left to resolve this issue", timeLeft.Round(time.Minute).String())
			} else {
				slaBreachRisk = "low"
				reasonDurationInfo = fmt.Sprintf("there are %s remaining before SLA breach", timeLeft.Round(time.Minute).String())
			}
		}
	} else {
		reasonDurationInfo = "SLA is not set"
	}

	duties, action := ai.GetSubDeptDutiesAndAction(p.SubDepartmentCode)

	var prefix string
	if isMismatch {
		prefix = fmt.Sprintf("System Rule Engine detected a critical input mismatch. User selected '%s', but content matched '%s' disaster keywords. Category automatically corrected. ", originalCategory, correctedCategory)
	} else {
		prefix = fmt.Sprintf("Ticket was automatically escalated to %s urgency by the System Rule Engine due to matching critical disaster keywords. ", p.Priority)
	}

	slaBreachRiskUpper := strings.ToUpper(slaBreachRisk)
	reasonSummary := fmt.Sprintf("%sRouted to %s (%s) on %s as it involves %s. SLA breach risk is %s because %s.",
		prefix, p.SubDepartmentCode, p.Name, p.Floor, duties, slaBreachRiskUpper, reasonDurationInfo)

	recommendedNextAction := fmt.Sprintf("%s Route the request to the '%s' team located at %s.",
		action, p.Name, p.Floor)

	return slaBreachRisk, reasonSummary, recommendedNextAction
}
