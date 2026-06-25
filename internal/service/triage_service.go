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

	// Layer 1: Content Safety Filter + input validation (inside buildTriageContext)
	ticket, promptData, err := s.buildTriageContext(ctx, ticketID)
	if err != nil {
		return nil, err
	}

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
			s.asyncUpdateTicketCategory(ticketID, correctedCategory)
		} else {
			slog.InfoContext(ctx, "Urgency Level Rule Engine short-circuit triggered",
				slog.Uint64("ticket_id", uint64(ticketID)),
				slog.String("category", string(ticket.Category)),
				slog.String("urgency_level", ruleResult.UrgencyLevel),
				slog.String("sla_breach_risk", ruleResult.SLABreachRisk),
			)
		}
		dbResult := triageResultFromResponse(ticket.ID, ruleResult)
		if err := s.saveTriageResult(ctx, ticketID, dbResult); err != nil {
			return nil, err
		}
		return ruleResult, nil
	}

	// Layer 3: Field Selector + RAG Retrieval
	vec, _ := s.generateEmbedding(ctx, ticket.Title, ticket.Description)
	ragContext, shortCircuitResp, ragErr := s.executeRAGLayer(ctx, ticketID, ticket, vec, promptData)
	if ragErr != nil {
		return nil, ragErr
	}
	if shortCircuitResp != nil {
		return shortCircuitResp, nil
	}
	promptData.KnowledgeContext = ragContext

	// Layer 4: AI Classification — send enriched prompt to LLM via Fallback Chain
	aiRaw, aiErr := s.runAIClassification(ctx, ticketID, promptData)
	finalResult := ai.ApplyFallbackIfNeeded(aiRaw, aiErr, ticket)

	// Layer 5: Persist result + return response
	dbResult := triageResultFromAI(ticket.ID, finalResult)
	if err := s.saveTriageResult(ctx, ticketID, dbResult); err != nil {
		return nil, err
	}

	slog.InfoContext(ctx, "triage completed successfully",
		slog.Uint64("ticket_id", uint64(ticketID)),
		slog.Bool("fallback_used", finalResult.FallbackUsed),
	)
	return toTriageResponse(dbResult), nil
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

// toTriageResponse converts an AITicketTriageResult model to a TriageResponse DTO.
func toTriageResponse(r *model.AITicketTriageResult) *response.TriageResponse {
	return &response.TriageResponse{
		Category:              r.Category,
		UrgencyLevel:          r.UrgencyLevel,
		SLABreachRisk:         r.SLABreachRisk,
		ReasonSummary:         r.ReasonSummary,
		RecommendedNextAction: r.RecommendedNextAction,
		ConfidenceScore:       r.ConfidenceScore,
		FallbackUsed:          r.FallbackUsed,
		PromptVersion:         r.PromptVersion,
	}
}

// saveTriageResult persists a triage result to the database.
func (s *triageServiceImpl) saveTriageResult(ctx context.Context, ticketID uint, dbResult *model.AITicketTriageResult) error {
	if err := s.triageRepo.Create(ctx, dbResult); err != nil {
		slog.ErrorContext(ctx, "failed to save triage result",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.Any("db_error", err),
		)
		return fmt.Errorf("failed to save triage result: %w", err)
	}
	return nil
}

// triageResultFromResponse builds an AITicketTriageResult from a TriageResponse DTO.
func triageResultFromResponse(ticketID uint, r *response.TriageResponse) *model.AITicketTriageResult {
	return &model.AITicketTriageResult{
		TicketID:              ticketID,
		Category:              r.Category,
		UrgencyLevel:          r.UrgencyLevel,
		SLABreachRisk:         r.SLABreachRisk,
		ReasonSummary:         r.ReasonSummary,
		RecommendedNextAction: r.RecommendedNextAction,
		ConfidenceScore:       r.ConfidenceScore,
		FallbackUsed:          r.FallbackUsed,
		PromptVersion:         r.PromptVersion,
	}
}

// triageResultFromAI builds an AITicketTriageResult from a raw ai.TriageResult.
func triageResultFromAI(ticketID uint, r *ai.TriageResult) *model.AITicketTriageResult {
	return &model.AITicketTriageResult{
		TicketID:              ticketID,
		Category:              r.Category,
		UrgencyLevel:          r.UrgencyLevel,
		SLABreachRisk:         r.SLABreachRisk,
		ReasonSummary:         r.ReasonSummary,
		RecommendedNextAction: r.RecommendedNextAction,
		ConfidenceScore:       r.ConfidenceScore,
		FallbackUsed:          r.FallbackUsed,
		PromptVersion:         r.PromptVersion,
	}
}

// asyncUpdateTicketCategory asynchronously corrects the ticket category in the database.
func (s *triageServiceImpl) asyncUpdateTicketCategory(ticketID uint, correctedCategory string) {
	go func() {
		bgCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := s.ticketRepo.UpdateCategory(bgCtx, ticketID, model.TicketCategory(correctedCategory)); err != nil {
			slog.Error("failed to asynchronously update ticket category in DB",
				slog.Uint64("ticket_id", uint64(ticketID)),
				slog.String("category", correctedCategory),
				slog.Any("error", err),
			)
		} else {
			slog.Info("asynchronously updated ticket category in DB successfully",
				slog.Uint64("ticket_id", uint64(ticketID)),
				slog.String("category", correctedCategory),
			)
		}
	}()
}

// resolveRAGThresholds returns (shortCircuitThreshold, contextThreshold) from config with safe defaults.
func (s *triageServiceImpl) resolveRAGThresholds() (shortCircuit, contextThreshold float64) {
	shortCircuit = 0.5
	contextThreshold = 0.4
	if s.cfg != nil {
		if s.cfg.AIRagThreshold > 0 {
			shortCircuit = s.cfg.AIRagThreshold
		}
		if s.cfg.AIRagContextThreshold > 0 {
			contextThreshold = s.cfg.AIRagContextThreshold
		}
	}
	if contextThreshold >= shortCircuit {
		contextThreshold = shortCircuit - 0.4
	}
	return shortCircuit, contextThreshold
}

// generateEmbedding normalizes ticket text and returns an embedding vector.
// Returns nil vector (and nil error) if no embeddingClient is configured.
func (s *triageServiceImpl) generateEmbedding(ctx context.Context, title, description string) ([]float32, error) {
	if s.embeddingClient == nil {
		return nil, nil
	}
	normalizedText := ai.NormalizeTicketForEmbedding(title, description)
	slog.InfoContext(ctx, "RAG: normalized text for embedding", slog.String("text", normalizedText))
	vec, err := s.embeddingClient.GetEmbedding(ctx, normalizedText)
	if err != nil {
		slog.WarnContext(ctx, "RAG: failed to get embedding, proceeding without RAG", slog.Any("error", err))
		return nil, err
	}
	return vec, nil
}

// executeRAGLayer performs vector search, short-circuits on high-similarity match,
// or returns enriched RAG context string for the AI prompt.
// Returns (ragContext, triageResponse, error). If triageResponse != nil, caller should return it immediately.
func (s *triageServiceImpl) executeRAGLayer(ctx context.Context, ticketID uint, ticket *model.Ticket, vec []float32, promptData ai.TriagePromptData) (string, *response.TriageResponse, error) {
	if vec == nil || s.kbRepo == nil {
		return "", nil, nil
	}

	shortCircuitThreshold, contextThreshold := s.resolveRAGThresholds()

	similarTickets, err := s.kbRepo.SearchSimilarTickets(ctx, vec, 3, contextThreshold)
	if err != nil {
		slog.WarnContext(ctx, "RAG: search tickets failed", slog.Any("error", err))
	}

	if len(similarTickets) > 0 {
		top := similarTickets[0]
		slog.InfoContext(ctx, "RAG: top-1 match similarity",
			slog.Uint64("ticket_id", uint64(ticketID)),
			slog.Uint64("matched_sample_id", uint64(top.ID)),
			slog.Float64("similarity", top.Similarity),
			slog.Float64("similarity_pct", top.Similarity*100),
			slog.Float64("short_circuit_threshold", shortCircuitThreshold),
			slog.Bool("will_short_circuit", top.Similarity >= shortCircuitThreshold),
		)

		if top.Similarity >= shortCircuitThreshold {
			slog.InfoContext(ctx, "RAG short-circuit: high-similarity sample found, bypassing AI",
				slog.Uint64("ticket_id", uint64(ticketID)),
				slog.Uint64("matched_sample_id", uint64(top.ID)),
				slog.Float64("similarity", top.Similarity),
				slog.Float64("threshold", shortCircuitThreshold),
			)

			reasonSummary := top.TriageReasonSummary
			slaBreachRisk := top.TriageSLABreachRisk
			timeLeftStr := "Unknown"

			if ticket.SLADueAt != nil {
				now := time.Now()
				if now.After(*ticket.SLADueAt) {
					reasonSummary += fmt.Sprintf(" SLA is overdue by %s", now.Sub(*ticket.SLADueAt).Round(time.Minute).String())
					slaBreachRisk = "overdue"
					timeLeftStr = "Overdue"
				} else {
					timeLeft := ticket.SLADueAt.Sub(now)
					timeLeftStr = timeLeft.Round(time.Minute).String()
					reasonSummary += fmt.Sprintf(" Time remaining before SLA breach: %s", timeLeftStr)
					if timeLeft <= 4*time.Hour {
						slaBreachRisk = "high"
					} else if timeLeft <= 24*time.Hour && slaBreachRisk == "low" {
						slaBreachRisk = "medium"
					}
				}
			}

			if len(promptData.Events) > 0 {
				lastEvent := promptData.Events[len(promptData.Events)-1]
				reasonSummary += fmt.Sprintf(". The history event: %s with note: %s", string(lastEvent.ToStatus), lastEvent.Note)
			}

			recommendedNextAction := top.TriageRecommendedNextAction
			if ticket.Status != model.StatusNew && len(promptData.Events) > 0 {
				nextActionData := ai.NextActionPromptData{
					ReasonSummary: reasonSummary,
					TimeLeft:      timeLeftStr,
					Events:        promptData.Events,
				}
				slog.InfoContext(ctx, "invoking Next-Action Agent for short-circuited ticket", slog.Uint64("ticket_id", uint64(ticketID)))
				action, err := s.aiAdapter.DetermineNextAction(ctx, nextActionData)
				if err != nil {
					slog.WarnContext(ctx, "failed to get next action from AI, falling back to static", slog.Any("error", err))
				} else if action != "" {
					recommendedNextAction = action
				}
			}

			dbResult := &model.AITicketTriageResult{
				TicketID:              ticket.ID,
				Category:              top.TriageCategory,
				UrgencyLevel:          top.TriageUrgencyLevel,
				SLABreachRisk:         slaBreachRisk,
				ReasonSummary:         reasonSummary,
				RecommendedNextAction: recommendedNextAction,
				ConfidenceScore:       top.Similarity,
				FallbackUsed:          false,
			}
			if err := s.saveTriageResult(ctx, ticketID, dbResult); err != nil {
				return "", nil, err
			}
			return "", toTriageResponse(dbResult), nil
		}
	}

	departments, deptErr := s.kbRepo.SearchSimilarDepartments(ctx, vec, 1, contextThreshold)
	if deptErr != nil {
		slog.WarnContext(ctx, "RAG: search departments failed", slog.Any("error", deptErr))
	}

	ragContext := s.buildRAGContext(departments, similarTickets)
	slog.InfoContext(ctx, "RAG context built, proceeding to AI",
		slog.Uint64("ticket_id", uint64(ticketID)),
		slog.Int("matched_tickets", len(similarTickets)),
		slog.Int("matched_departments", len(departments)),
	)
	return ragContext, nil, nil
}

// runAIClassification calls the AI adapter with a timeout, normalizes confidence score, and logs warnings.
func (s *triageServiceImpl) runAIClassification(ctx context.Context, ticketID uint, promptData ai.TriagePromptData) (*ai.TriageResult, error) {
	timeoutSecs := 15
	if s.cfg != nil && s.cfg.AITimeoutSecs > 0 {
		timeoutSecs = s.cfg.AITimeoutSecs
	}
	aiCtx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSecs)*time.Second)
	defer cancel()

	aiResult, aiErr := s.aiAdapter.AnalyzeTicket(aiCtx, promptData)

	if aiResult != nil && aiResult.ConfidenceScore > 1.0 {
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

	return aiResult, aiErr
}
