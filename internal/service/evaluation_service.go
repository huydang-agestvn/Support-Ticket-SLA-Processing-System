package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/config"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/errmsgs"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/repository"
)

type EvaluationService interface {
	RunTriageEvaluation(ctx context.Context, req request.AIEvaluationRequest) (*response.AIEvaluationResponse, error)
}

type evaluationServiceImpl struct {
	evaluationRepo  repository.EvaluationRepository
	reportRepo      repository.ReportRepository
	aiAdapter       ai.TriageAdapter
	triageRepo      repository.TriageRepository
	kbRepo          repository.KnowledgeBaseRepository
	embeddingClient *ai.EmbeddingClient
	cfg             *config.Config
}

func NewEvaluationService(
	evaluationRepo repository.EvaluationRepository,
	reportRepo repository.ReportRepository,
	aiAdapter ai.TriageAdapter,
	triageRepo repository.TriageRepository,
	kbRepo repository.KnowledgeBaseRepository,
	embeddingClient *ai.EmbeddingClient,
	cfg *config.Config,
) EvaluationService {
	return &evaluationServiceImpl{
		evaluationRepo:  evaluationRepo,
		reportRepo:      reportRepo,
		aiAdapter:       aiAdapter,
		triageRepo:      triageRepo,
		kbRepo:          kbRepo,
		embeddingClient: embeddingClient,
		cfg:             cfg,
	}
}

func (s *evaluationServiceImpl) RunTriageEvaluation(ctx context.Context, req request.AIEvaluationRequest) (*response.AIEvaluationResponse, error) {
	if err := s.validateRequest(req); err != nil {
		slog.WarnContext(ctx, "invalid evaluation request", slog.Any("error", err))
		return nil, err
	}

	relativeTemplatePath := fmt.Sprintf("internal/ai/prompts/triage_%s.tmpl", req.PromptVersion)
	templatePath, err := s.resolveTemplatePath(relativeTemplatePath)
	if err != nil {
		slog.WarnContext(ctx, "prompt template validation failed", slog.Any("template_path", relativeTemplatePath), slog.Any("error", err))
		return nil, common.NewBadRequest(common.ErrCodeInvalidInput, fmt.Sprintf("prompt version template %s not found", relativeTemplatePath))
	}

	if err := s.validateTemplateExists(templatePath); err != nil {
		slog.WarnContext(ctx, "prompt template validation failed", slog.Any("template_path", templatePath), slog.Any("error", err))
		return nil, err
	}

	cases, err := s.evaluationRepo.GetCases(ctx, req.EvaluationCaseIDs)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch evaluation cases", slog.Any("error", err), slog.Any("case_ids", req.EvaluationCaseIDs))
		return nil, fmt.Errorf("%w: failed to fetch evaluation cases", errmsgs.ErrInternal)
	}
	if len(cases) == 0 {
		slog.WarnContext(ctx, "evaluation case list empty", slog.Any("case_ids", req.EvaluationCaseIDs))
		return nil, common.NewBadRequest(common.ErrCodeInvalidInput, "no evaluation cases found")
	}

	evalRefTime := time.Date(2026, 6, 10, 9, 0, 0, 0, time.FixedZone("ICT", 7*3600))
	report := s.loadDailyReport(ctx, evalRefTime)

	startTime := time.Now()
	caseResults, passedCases, failedCases, totalLatencyMs, err := s.evaluateCases(ctx, cases, report, evalRefTime, req.PromptVersion)
	if err != nil {
		return nil, err
	}

	totalDurationMs := time.Since(startTime).Milliseconds()
	avgLatency := int64(0)
	if len(cases) > 0 {
		avgLatency = totalLatencyMs / int64(len(cases))
	}
	throughput := float64(0)
	if totalDurationMs > 0 {
		throughput = float64(len(cases)) / (float64(totalDurationMs) / 1000.0)
	}

	accuracyRate := float64(0)
	if len(cases) > 0 {
		accuracyRate = (float64(passedCases) / float64(len(cases))) * 100.0
	}

	detailsBytes, err := json.Marshal(caseResults)
	if err != nil {
		slog.ErrorContext(ctx, "failed to marshal evaluation results", slog.Any("error", err))
		return nil, fmt.Errorf("%w: failed to marshal case results", errmsgs.ErrInternal)
	}

	createdBy := "system"
	if userVal := ctx.Value("current_user"); userVal != nil {
		if u, ok := userVal.(auth.UserPrincipal); ok && u.Username != "" {
			createdBy = u.Username
		}
	}

	runModel := &model.AIEvaluationRun{
		Name:          fmt.Sprintf("Evaluation Run %s - %s", req.PromptVersion, time.Now().Format("2006-01-02 15:04:05")),
		ModelUsed:     s.aiAdapter.Model(),
		PromptVersion: req.PromptVersion,
		TotalCases:    len(cases),
		PassedCases:   passedCases,
		FailedCases:   failedCases,
		AccuracyRate:  accuracyRate,
		AvgLatencyMs:  avgLatency,
		FallbackUsed:  false,
		DetailsRaw:    json.RawMessage(detailsBytes),
		AuditModel: model.AuditModel{
			CreatedBy: createdBy,
			UpdatedBy: createdBy,
		},
	}

	if err := s.evaluationRepo.CreateRun(ctx, runModel); err != nil {
		slog.ErrorContext(ctx, "failed to save evaluation run", slog.Any("error", err))
		return nil, fmt.Errorf("%w: failed to save evaluation run", errmsgs.ErrInternal)
	}

	resp := &response.AIEvaluationResponse{
		RunID:         runModel.ID,
		RunDate:       runModel.CreatedAt,
		PromptVersion: runModel.PromptVersion,
		DetailRaw:     runModel.DetailsRaw,
		Metrics: response.AIEvaluationMetrics{
			Accuracy: response.AccuracyMetrics{
				TotalCases:   runModel.TotalCases,
				PassedCases:  runModel.PassedCases,
				FailedCases:  runModel.FailedCases,
				AccuracyRate: runModel.AccuracyRate,
			},
			Performance: response.PerformanceMetrics{
				TotalDurationMs: totalDurationMs,
				AvgLatencyMs:    runModel.AvgLatencyMs,
				ThroughputCPS:   throughput,
			},
			// ResourceUsage: response.ResourceUsageMetrics{
			// 	TotalPromptTokens:     0,
			// 	TotalCompletionTokens: 0,
			// 	TotalTokens:           0,
			// 	EstimatedCostUSD:      0.0,
			// },
		},
	}

	return resp, nil
}

func (s *evaluationServiceImpl) validateRequest(req request.AIEvaluationRequest) error {
	if strings.TrimSpace(req.PromptVersion) == "" {
		return errmsgs.ErrPromptVersionRequired
	}
	if len(req.EvaluationCaseIDs) == 0 {
		return errmsgs.ErrEvaluationCaseIDsRequired
	}
	return nil
}

func (s *evaluationServiceImpl) resolveTemplatePath(relativePath string) (string, error) {
	currentDir, err := os.Getwd()
	if err != nil {
		return "", err
	}

	for {
		candidate := filepath.Join(currentDir, relativePath)
		if _, err := os.Stat(candidate); err == nil {
			return candidate, nil
		}

		parentDir := filepath.Dir(currentDir)
		if parentDir == currentDir {
			break
		}
		currentDir = parentDir
	}

	return "", fmt.Errorf("template path not found")
}

func (s *evaluationServiceImpl) validateTemplateExists(path string) error {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return common.NewBadRequest(common.ErrCodeInvalidInput, fmt.Sprintf("prompt version template %s not found", path))
	}
	return nil
}

func (s *evaluationServiceImpl) loadDailyReport(ctx context.Context, evalRefTime time.Time) *model.TicketReport {
	report, err := s.reportRepo.GetByDate(evalRefTime)
	if err == nil {
		return report
	}

	report, err = s.reportRepo.GetByDate(evalRefTime.Add(-24 * time.Hour))
	if err == nil {
		return report
	}

	return nil
}

func (s *evaluationServiceImpl) evaluateCases(
	ctx context.Context,
	cases []model.AIEvaluationCase,
	report *model.TicketReport,
	evalRefTime time.Time,
	promptVersion string,
) ([]model.EvaluationCaseResult, int, int, int64, error) {
	var caseResults []model.EvaluationCaseResult
	passedCases := 0
	failedCases := 0
	var totalLatencyMs int64

	for _, caseItem := range cases {
		var ticket model.Ticket
		if err := json.Unmarshal([]byte(caseItem.InputSnapshot), &ticket); err != nil {
			return nil, 0, 0, 0, common.NewBadRequest(common.ErrCodeInvalidInput, fmt.Sprintf("failed to parse input snapshot for case %d", caseItem.ID))
		}
		ticketNow := evalRefTime
		var meta struct {
			EvaluationCurrentTime string `json:"evaluation_current_time"`
		}
		if err := json.Unmarshal([]byte(caseItem.InputSnapshot), &meta); err == nil && strings.TrimSpace(meta.EvaluationCurrentTime) != "" {
			if t, err := time.Parse(time.RFC3339, meta.EvaluationCurrentTime); err == nil {
				ticketNow = t
			} else {
				slog.WarnContext(ctx, "failed to parse evaluation_current_time in snapshot", slog.Any("case_id", caseItem.ID), slog.Any("value", meta.EvaluationCurrentTime), slog.Any("error", err))
			}
		}

		if ticketNow.Before(ticket.CreatedAt) {
			ticketNow = ticket.CreatedAt
		}

		// Calculate the offset to shift timestamps so that ticketNow becomes time.Now()
		timeOffset := time.Now().Sub(ticketNow)
		ticket.CreatedAt = ticket.CreatedAt.Add(timeOffset)
		ticket.TicketCreatedAt = ticket.TicketCreatedAt.Add(timeOffset)
		if ticket.SLADueAt != nil {
			shiftedDue := ticket.SLADueAt.Add(timeOffset)
			ticket.SLADueAt = &shiftedDue
		}
		for i := range ticket.Events {
			ticket.Events[i].CreatedAt = ticket.Events[i].CreatedAt.Add(timeOffset)
		}

		if err := s.validateDueDate(ctx, ticket, time.Now(), caseItem.ID); err != nil {
			slog.WarnContext(ctx, "ticket SLA due date validation failed", slog.Any("case_id", uint(caseItem.ID)), slog.Any("error", err))
			return nil, 0, 0, 0, err
		}

		caseStartTime := time.Now()
		triageRes, err := s.runLocalTriage(ctx, &ticket, report, promptVersion)
		latency := time.Since(caseStartTime).Milliseconds()
		totalLatencyMs += latency

		if err != nil {
			failedCases++
			caseResults = append(caseResults, model.EvaluationCaseResult{
				TestCaseID:          int64(caseItem.ID),
				ActualCategory:      "",
				ActualUrgency:       "",
				ActualSLABreachRisk: "",
				IsOverallPassed:     false,
				FailureReason:       fmt.Sprintf("Local triage error: %v", err),
				LatencyMs:           latency,
			})
			continue
		}

		categoryPassed := strings.EqualFold(triageRes.Category, caseItem.ExpectedCategory)
		urgencyPassed := strings.EqualFold(triageRes.UrgencyLevel, caseItem.ExpectedUrgency)
		slaPassed := strings.EqualFold(triageRes.SLABreachRisk, caseItem.ExpectedSLABreachRisk)

		isPassed := categoryPassed && urgencyPassed && slaPassed
		var failureReason string
		if !isPassed {
			var mismatches []string
			if !categoryPassed {
				mismatches = append(mismatches, fmt.Sprintf("Category (expected: %s, got: %s)", caseItem.ExpectedCategory, triageRes.Category))
			}
			if !urgencyPassed {
				mismatches = append(mismatches, fmt.Sprintf("Urgency (expected: %s, got: %s)", caseItem.ExpectedUrgency, triageRes.UrgencyLevel))
			}
			if !slaPassed {
				mismatches = append(mismatches, fmt.Sprintf("SLA Risk (expected: %s, got: %s)", caseItem.ExpectedSLABreachRisk, triageRes.SLABreachRisk))
			}
			failureReason = "Mismatch: " + strings.Join(mismatches, ", ")
		}

		if isPassed {
			passedCases++
		} else {
			failedCases++
		}

		caseResults = append(caseResults, model.EvaluationCaseResult{
			TestCaseID:          int64(caseItem.ID),
			ActualCategory:      triageRes.Category,
			ActualUrgency:       triageRes.UrgencyLevel,
			ActualSLABreachRisk: triageRes.SLABreachRisk,
			IsOverallPassed:     isPassed,
			RiskExplanation:     triageRes.ReasonSummary,
			FailureReason:       failureReason,
			LatencyMs:           latency,
		})
	}

	return caseResults, passedCases, failedCases, totalLatencyMs, nil
}

func (s *evaluationServiceImpl) runLocalTriage(
	ctx context.Context,
	ticket *model.Ticket,
	report *model.TicketReport,
	promptVersion string,
) (*ai.TriageResult, error) {
	// Layer 2: Rule Engine
	if s.triageRepo != nil {
		patterns, err := s.triageRepo.GetActiveRulePatterns(ctx)
		if err == nil && len(patterns) > 0 {
			combined := fmt.Sprintf("%s\n%s", ticket.Title, ticket.Description)
			combinedLower := strings.ToLower(combined)

			matchesPattern := func(p response.RulePatternResponse) bool {
				if p.PatternType == "regex" {
					re, err := regexp.Compile(p.Pattern)
					if err != nil {
						return false
					}
					return re.MatchString(combined)
				}
				return strings.Contains(combinedLower, strings.ToLower(p.Pattern))
			}

			var matchedPattern *response.RulePatternResponse
			originalCategory := string(ticket.Category)

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
					pCopy := p
					matchedPattern = &pCopy
					break
				}
			}

			// 2. Priority 2: Check other categories
			if matchedPattern == nil {
				for _, p := range patterns {
					var cat string
					if len(p.SubDepartmentCode) >= 2 {
						cat = ai.MapDeptCodeToCategory(p.SubDepartmentCode[:2])
					}
					if cat == originalCategory {
						continue
					}
					if matchesPattern(p) {
						pCopy := p
						matchedPattern = &pCopy
						break
					}
				}
			}

			if matchedPattern != nil {
				slaBreachRisk, reasonSummary, recommendedNextAction := s.calculateRuleEngineSLARisk(ticket.SLADueAt, matchedPattern)
				return &ai.TriageResult{
					Category:              matchedPattern.SubDepartmentCode, // Granular sub-department code
					UrgencyLevel:          string(matchedPattern.Priority),
					SLABreachRisk:         slaBreachRisk,
					ReasonSummary:         reasonSummary,
					RecommendedNextAction: recommendedNextAction,
					ConfidenceScore:       1.0,
					FallbackUsed:          false,
				}, nil
			}
		}
	}

	// Layer 3: RAG Retrieval / Similarity
	var vec []float32
	if s.embeddingClient != nil && s.kbRepo != nil {
		normalizedText := ai.NormalizeTicketForEmbedding(ticket.Title, ticket.Description)
		if v, err := s.embeddingClient.GetEmbedding(ctx, normalizedText); err == nil {
			vec = v
		}
	}

	var promptData ai.TriagePromptData
	promptData.Ticket = *ticket
	promptData.Events = ticket.Events
	promptData.SLAPolicy = "Max resolution time is determined as follows: High (4h), Medium (24h), Low (48h)."
	promptData.DailyReport = report
	promptData.TimeLeft = s.buildSLAEvidence(*ticket, time.Now())

	if vec != nil && s.kbRepo != nil {
		shortCircuitThreshold := 0.5
		contextThreshold := 0.4
		if s.cfg != nil {
			if s.cfg.AIRagThreshold > 0 {
				shortCircuitThreshold = s.cfg.AIRagThreshold
			}
			if s.cfg.AIRagContextThreshold > 0 {
				contextThreshold = s.cfg.AIRagContextThreshold
			}
		}
		if contextThreshold >= shortCircuitThreshold {
			contextThreshold = shortCircuitThreshold - 0.4
		}

		similarTickets, err := s.kbRepo.SearchSimilarTickets(ctx, vec, 3, contextThreshold)
		if err == nil && len(similarTickets) > 0 {
			top := similarTickets[0]
			if top.Similarity >= shortCircuitThreshold {
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

				if len(ticket.Events) > 0 {
					lastEvent := ticket.Events[len(ticket.Events)-1]
					reasonSummary += fmt.Sprintf(". The history event: %s with note: %s", string(lastEvent.ToStatus), lastEvent.Note)
				}

				recommendedNextAction := top.TriageRecommendedNextAction
				if ticket.Status != model.StatusNew && len(ticket.Events) > 0 {
					nextActionData := ai.NextActionPromptData{
						ReasonSummary: reasonSummary,
						TimeLeft:      timeLeftStr,
						Events:        ticket.Events,
					}
					action, err := s.aiAdapter.DetermineNextAction(ctx, nextActionData)
					if err == nil && action != "" {
						recommendedNextAction = action
					}
				}

				return &ai.TriageResult{
					Category:              top.SubDepartmentCode, // Granular sub-department code
					UrgencyLevel:          top.TriageUrgencyLevel,
					SLABreachRisk:         slaBreachRisk,
					ReasonSummary:         reasonSummary,
					RecommendedNextAction: recommendedNextAction,
					ConfidenceScore:       top.Similarity,
					FallbackUsed:          false,
				}, nil
			}
		}

		departments, deptErr := s.kbRepo.SearchSimilarDepartments(ctx, vec, 1, contextThreshold)
		if deptErr == nil && len(departments) > 0 {
			var sb strings.Builder
			sb.WriteString("# Relevant Knowledge Base Context (from Vector DB)\n")
			counter := 1
			for _, dept := range departments {
				sb.WriteString(fmt.Sprintf("%d. [policy | dept: %s | name: %s | floor: %s] %s\n", counter, dept.Code, dept.Name, dept.Floor, dept.Description))
				counter++
			}
			promptData.KnowledgeContext = sb.String()
		}
	}

	// Layer 4: AI Classifier / Fallback Chain
	aiRaw, aiErr := s.aiAdapter.AnalyzeTicketWithVersion(ctx, promptData, promptVersion)
	finalResult := ai.ApplyFallbackIfNeeded(aiRaw, aiErr, ticket)
	return finalResult, nil
}

func (s *evaluationServiceImpl) calculateRuleEngineSLARisk(
	slaDueAt *time.Time,
	p *response.RulePatternResponse,
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

	prefix := fmt.Sprintf("Ticket was automatically escalated to %s urgency by the System Rule Engine due to matching critical disaster keywords. ", p.Priority)
	reasonSummary := prefix + "The matched duties include: " + duties + ". Time status: " + reasonDurationInfo + "."

	return slaBreachRisk, reasonSummary, action
}

func (s *evaluationServiceImpl) validateDueDate(ctx context.Context, ticket model.Ticket, referenceTime time.Time, caseID uint) error {
	return nil
}

func (s *evaluationServiceImpl) buildSLAEvidence(ticket model.Ticket, referenceTime time.Time) string {
	if ticket.SLADueAt == nil {
		return "SLA not set."
	}

	timeLeft := ticket.SLADueAt.Sub(referenceTime).Round(time.Minute)
	return fmt.Sprintf("Ticket has %s remaining before SLA breach", timeLeft)
}
