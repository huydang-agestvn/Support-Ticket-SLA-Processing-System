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

// into a plain-text context string to inject into the AI prompt.
func (s *triageServiceImpl) buildRAGContext(departments []repository.DepartmentMatch, tickets []repository.TicketMatch) string {
	if len(departments) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("# Relevant Knowledge Base Context (from Vector DB)\n")

	counter := 1
	for _, dept := range departments {
		sb.WriteString(fmt.Sprintf("%d. [policy | dept: %s | name: %s | floor: %s] %s\n", counter, dept.Code, dept.Name, dept.Floor, dept.Description))
		counter++
	}

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

	// Layer 3: Field Selector + RAG Retrieval
	var vec []float32
	var embeddingErr error
	if s.embeddingClient != nil {
		// 1. Field Selector: normalize ticket text (title + description combined)
		normalizedText := ai.NormalizeTicketForEmbedding(ticket.Title, ticket.Description)
		slog.InfoContext(ctx, "RAG: normalized text for embedding", slog.String("text", normalizedText))
		// 2. Generate embedding vector via Ollama
		vec, embeddingErr = s.embeddingClient.GetEmbedding(ctx, normalizedText)
		if embeddingErr != nil {
			slog.WarnContext(ctx, "RAG: failed to get embedding, proceeding without RAG", slog.Any("error", embeddingErr))
		}
	}

	var ragContext string

	if embeddingErr == nil && vec != nil && s.kbRepo != nil {
		shortCircuitSimilarityThreshold := 0.5 
		contextSimilarityThreshold := 0.4    
		if s.cfg != nil {
			if s.cfg.AIRagThreshold > 0 {
				shortCircuitSimilarityThreshold = s.cfg.AIRagThreshold
			}
			if s.cfg.AIRagContextThreshold > 0 {
				contextSimilarityThreshold = s.cfg.AIRagContextThreshold
			}
		}
		if contextSimilarityThreshold >= shortCircuitSimilarityThreshold {
			contextSimilarityThreshold = shortCircuitSimilarityThreshold - 0.4
		}

		similarTickets, ticketSearchErr := s.kbRepo.SearchSimilarTickets(ctx, vec, 3, contextSimilarityThreshold)
		if ticketSearchErr != nil {
			slog.WarnContext(ctx, "RAG: search tickets failed", slog.Any("error", ticketSearchErr))
		}

		// Log top-1 match similarity for diagnostics
		if len(similarTickets) > 0 {
			slog.InfoContext(ctx, "RAG: top-1 match similarity",
				slog.Uint64("ticket_id", uint64(ticketID)),
				slog.Uint64("matched_sample_id", uint64(similarTickets[0].ID)),
				slog.Float64("similarity", similarTickets[0].Similarity),
				slog.Float64("similarity_pct", similarTickets[0].Similarity*100),
				slog.Float64("short_circuit_threshold", shortCircuitSimilarityThreshold),
				slog.Bool("will_short_circuit", similarTickets[0].Similarity >= shortCircuitSimilarityThreshold),
			)
		}

		// RAG Short-circuit: Top-1 similarity >= threshold → high similarity → skip AI, return cached result
		if len(similarTickets) > 0 && similarTickets[0].Similarity >= shortCircuitSimilarityThreshold {
			closest := similarTickets[0]
			slog.InfoContext(ctx, "RAG short-circuit: high-similarity sample found, bypassing AI",
				slog.Uint64("ticket_id", uint64(ticketID)),
				slog.Uint64("matched_sample_id", uint64(closest.ID)),
				slog.Float64("similarity", closest.Similarity),
				slog.Float64("similarity_pct", closest.Similarity*100),
				slog.Float64("threshold", shortCircuitSimilarityThreshold),
			)

			dbResult := &model.AITicketTriageResult{
				TicketID:              ticket.ID,
				Category:              closest.TriageCategory,
				UrgencyLevel:          closest.TriageUrgencyLevel,
				SLABreachRisk:         closest.TriageSLABreachRisk,
				ReasonSummary:         closest.TriageReasonSummary,
				RecommendedNextAction: closest.TriageRecommendedNextAction,
				ConfidenceScore:       closest.TriageConfidenceScore,
				FallbackUsed:          false,
			}

			if err := s.triageRepo.Create(ctx, dbResult); err != nil {
				slog.ErrorContext(ctx, "failed to save RAG short-circuit result",
					slog.Uint64("ticket_id", uint64(ticketID)),
					slog.Any("db_error", err),
				)
				return nil, fmt.Errorf("failed to save triage result: %w", err)
			}

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

		// No short-circuit: enrich AI prompt with top-N context from vector DB
		departments, deptSearchErr := s.kbRepo.SearchSimilarDepartments(ctx, vec, 1, contextSimilarityThreshold)
		if deptSearchErr != nil {
			slog.WarnContext(ctx, "RAG: search departments failed", slog.Any("error", deptSearchErr))
		}

		ragContext = s.buildRAGContext(departments, similarTickets)
		slog.InfoContext(ctx, "RAG context built, proceeding to AI",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.Int("matched_tickets", len(similarTickets)),
			slog.Int("matched_departments", len(departments)),
		)
	}

	promptData.KnowledgeContext = ragContext

	// Layer 4: AI Classification — send enriched prompt to LLM via Fallback Chain
	timeoutSecs := 15
	if s.cfg != nil && s.cfg.AITimeoutSecs > 0 {
		timeoutSecs = s.cfg.AITimeoutSecs
	}
	aiCtx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSecs)*time.Second)
	defer cancel()

	aiResult, aiErr := s.aiAdapter.AnalyzeTicket(aiCtx, promptData)

	if aiResult.ConfidenceScore > 1.0 {
		aiResult.ConfidenceScore = aiResult.ConfidenceScore / 100.0
	}

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
			if timeLeft <= 4*time.Hour {
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
