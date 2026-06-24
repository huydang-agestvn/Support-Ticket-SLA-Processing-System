package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"time"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/auth"
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
	evaluationRepo repository.EvaluationRepository
	reportRepo     repository.ReportRepository
	aiAdapter      ai.TriageAdapter
}

func NewEvaluationService(
	evaluationRepo repository.EvaluationRepository,
	reportRepo repository.ReportRepository,
	aiAdapter ai.TriageAdapter,
) EvaluationService {
	return &evaluationServiceImpl{
		evaluationRepo: evaluationRepo,
		reportRepo:     reportRepo,
		aiAdapter:      aiAdapter,
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

		if err := s.validateDueDate(ctx, ticket, ticketNow, caseItem.ID); err != nil {
			slog.WarnContext(ctx, "ticket SLA due date validation failed", slog.Any("case_id", uint(caseItem.ID)), slog.Any("error", err))
			return nil, 0, 0, 0, err
		}

		promptData := ai.TriagePromptData{
			Ticket:      ticket,
			Events:      ticket.Events,
			SLAPolicy:   "Max resolution time is determined as follows: High (4h), Medium (24h), Low (48h).",
			DailyReport: report,
			TimeLeft:    s.buildSLAEvidence(ticket, ticketNow),
		}

		caseStartTime := time.Now()
		triageRes, err := s.aiAdapter.AnalyzeTicketWithVersion(ctx, promptData, promptVersion)
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
				FailureReason:       fmt.Sprintf("AI adapter error: %v", err),
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

func (s *evaluationServiceImpl) validateDueDate(ctx context.Context, ticket model.Ticket, referenceTime time.Time, caseID uint) error {
	if ticket.SLADueAt == nil {
		return nil
	}
	if referenceTime.After(*ticket.SLADueAt) {
		slog.WarnContext(ctx, "ticket SLA due date expired", slog.Any("case_id", uint(caseID)), slog.Time("due_at", *ticket.SLADueAt), slog.Time("reference_time", referenceTime))
		return errmsgs.ErrEvaluationCaseExpired
	}
	return nil
}

func (s *evaluationServiceImpl) buildSLAEvidence(ticket model.Ticket, referenceTime time.Time) string {
	if ticket.SLADueAt == nil {
		return "SLA not set."
	}

	timeLeft := ticket.SLADueAt.Sub(referenceTime).Round(time.Minute)
	return fmt.Sprintf("Ticket has %s remaining before SLA breach", timeLeft)
}
