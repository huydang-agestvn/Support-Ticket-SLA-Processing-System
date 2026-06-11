package service

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
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
	// 1. Verify prompt version template exists on disk
	templatePath := fmt.Sprintf("prompts/triage_%s.tmpl", req.PromptVersion)
	if _, err := os.Stat(templatePath); os.IsNotExist(err) {
		return nil, fmt.Errorf("prompt version template %s not found", templatePath)
	}

	// 2. Load test cases from DB
	cases, err := s.evaluationRepo.GetCases(ctx, req.EvaluationCaseIDs)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch evaluation cases: %w", err)
	}
	if len(cases) == 0 {
		return nil, fmt.Errorf("no evaluation cases found")
	}

	evalRefTime := time.Date(2026, 6, 10, 9, 0, 0, 0, time.FixedZone("ICT", 7*3600))

	report, err := s.reportRepo.GetByDate(evalRefTime)
	if err != nil {
		report, _ = s.reportRepo.GetByDate(evalRefTime.Add(-24 * time.Hour))
	}

	var caseResults []model.EvaluationCaseResult
	passedCases := 0
	failedCases := 0
	var totalLatencyMs int64 = 0

	startTime := time.Now()

	for _, caseItem := range cases {
		var ticket model.Ticket
		if err := json.Unmarshal([]byte(caseItem.InputSnapshot), &ticket); err != nil {
			return nil, fmt.Errorf("failed to unmarshal input snapshot for case %d: %w", caseItem.ID, err)
		}

		ticketNow := evalRefTime
		if ticketNow.Before(ticket.CreatedAt) {
			ticketNow = ticket.CreatedAt
		}

		slaEvidence := "SLA not set."
		if ticket.SLADueAt != nil {
			timeLeft := ticket.SLADueAt.Sub(ticketNow).Round(time.Minute)
			slaEvidence = fmt.Sprintf("Ticket has %s remaining before SLA breach", timeLeft)
		}

		promptData := ai.TriagePromptData{
			Ticket:      ticket,
			Events:      ticket.Events,
			SLAPolicy:   "Max resolution time is determined by priority: High (4h), Medium (24h), Low (48h).",
			DailyReport: report,
			TimeLeft:    slaEvidence,
		}

		caseStartTime := time.Now()
		triageRes, err := s.aiAdapter.AnalyzeTicketWithVersion(ctx, promptData, req.PromptVersion)
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

		// Compare predictions with expectations
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

	// 5. Save evaluation run to DB
	detailsBytes, err := json.Marshal(caseResults)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal case results: %w", err)
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
		return nil, fmt.Errorf("failed to save evaluation run: %w", err)
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
			ResourceUsage: response.ResourceUsageMetrics{
				TotalPromptTokens:     0,
				TotalCompletionTokens: 0,
				TotalTokens:           0,
				EstimatedCostUSD:      0.0,
			},
		},
	}

	return resp, nil
}
