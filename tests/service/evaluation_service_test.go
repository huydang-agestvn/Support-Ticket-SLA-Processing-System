package service_test

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/service"
	testmock "support-ticket.com/tests/mock"
)

func TestEvaluationService_RunTriageEvaluation(t *testing.T) {
	// Navigate up to the project root directory where the "prompts" directory is located
	origWD, err := os.Getwd()
	assert.NoError(t, err)
	
	for {
		if _, err := os.Stat("prompts"); err == nil {
			break
		}
		err := os.Chdir("..")
		if err != nil {
			break
		}
	}
	defer os.Chdir(origWD)

	// Setup a dummy prompt file for testing
	dummyPromptVersion := "test_v1.0"
	dummyPromptPath := "prompts/triage_test_v1.0.tmpl"
	
	err = os.WriteFile(dummyPromptPath, []byte("Title: {{.Ticket.Title}}\nTimeLeft: {{.TimeLeft}}"), 0644)
	assert.NoError(t, err)
	defer os.Remove(dummyPromptPath)

	// Sample Test Case
	inputSnapshot := `{
		"id": 101,
		"title": "Database Connection Pool Exhausted",
		"description": "Production database is dropping connections.",
		"priority": "high",
		"status": "new",
		"created_at": "2026-06-10T08:00:00+07:00",
		"sla_due_at": "2026-06-10T10:00:00+07:00",
		"events": []
	}`

	mockCases := []model.AIEvaluationCase{
		{
			ID:                    1,
			TestTitle:             "Category & Urgency - Core IT Infrastructure Failure",
			InputSnapshot:         inputSnapshot,
			ExpectedCategory:      "IT",
			ExpectedUrgency:       "high",
			ExpectedSLABreachRisk: "high",
		},
	}

	tests := []struct {
		name          string
		promptVersion string
		caseIDs       []uint
		mockRepo      func(*testmock.MockEvaluationRepository, *testmock.MockReportRepository)
		mockAdapter   func(*testmock.MockTriageAdapter)
		expectedError string
		validateRes   func(*testing.T, *model.AIEvaluationRun)
	}{
		{
			name:          "Template NotFound Error",
			promptVersion: "nonexistent_v1.0",
			caseIDs:       []uint{1},
			mockRepo:      func(e *testmock.MockEvaluationRepository, r *testmock.MockReportRepository) {},
			mockAdapter:   func(a *testmock.MockTriageAdapter) {},
			expectedError: "prompt version template prompts/triage_nonexistent_v1.0.tmpl not found",
		},
		{
			name:          "No Cases Found Error",
			promptVersion: dummyPromptVersion,
			caseIDs:       []uint{999},
			mockRepo: func(e *testmock.MockEvaluationRepository, r *testmock.MockReportRepository) {
				e.On("GetCases", mock.Anything, []uint{999}).Return([]model.AIEvaluationCase(nil), nil)
			},
			mockAdapter:   func(a *testmock.MockTriageAdapter) {},
			expectedError: "no evaluation cases found",
		},
		{
			name:          "Success Evaluation Run",
			promptVersion: dummyPromptVersion,
			caseIDs:       []uint{1},
			mockRepo: func(e *testmock.MockEvaluationRepository, r *testmock.MockReportRepository) {
				e.On("GetCases", mock.Anything, []uint{1}).Return(mockCases, nil)
				r.On("GetByDate", mock.Anything).Return((*model.TicketReport)(nil), errors.New("report not found"))
			},
			mockAdapter: func(a *testmock.MockTriageAdapter) {
				a.On("Model").Return("llama-3-test")
				a.On("AnalyzeTicketWithVersion", mock.Anything, mock.Anything, dummyPromptVersion).Return(&ai.TriageResult{
					Category:              "IT",
					UrgencyLevel:          "high",
					SLABreachRisk:         "high",
					ReasonSummary:         "Matched expected results perfectly.",
					RecommendedNextAction: "Verify DB settings",
					ConfidenceScore:       0.95,
					FallbackUsed:          false,
				}, nil)
			},
			validateRes: func(t *testing.T, run *model.AIEvaluationRun) {
				assert.Equal(t, 1, run.TotalCases)
				assert.Equal(t, 1, run.PassedCases)
				assert.Equal(t, 0, run.FailedCases)
				assert.Equal(t, 100.0, run.AccuracyRate)
				assert.Equal(t, "llama-3-test", run.ModelUsed)
				
				var details []model.EvaluationCaseResult
				err := json.Unmarshal([]byte(run.DetailsRaw), &details)
				assert.NoError(t, err)
				assert.Len(t, details, 1)
				assert.Equal(t, int64(1), details[0].TestCaseID)
				assert.Equal(t, "IT", details[0].ActualCategory)
				assert.True(t, details[0].IsOverallPassed)
			},
		},
		{
			name:          "Failed Case Match",
			promptVersion: dummyPromptVersion,
			caseIDs:       []uint{1},
			mockRepo: func(e *testmock.MockEvaluationRepository, r *testmock.MockReportRepository) {
				e.On("GetCases", mock.Anything, []uint{1}).Return(mockCases, nil)
				r.On("GetByDate", mock.Anything).Return((*model.TicketReport)(nil), errors.New("report not found"))
			},
			mockAdapter: func(a *testmock.MockTriageAdapter) {
				a.On("Model").Return("llama-3-test")
				a.On("AnalyzeTicketWithVersion", mock.Anything, mock.Anything, dummyPromptVersion).Return(&ai.TriageResult{
					Category:              "Facilities",
					UrgencyLevel:          "low",
					SLABreachRisk:         "low",
					ReasonSummary:         "Mismatch output.",
					RecommendedNextAction: "Action",
					ConfidenceScore:       0.4,
					FallbackUsed:          false,
				}, nil)
			},
			validateRes: func(t *testing.T, run *model.AIEvaluationRun) {
				assert.Equal(t, 1, run.TotalCases)
				assert.Equal(t, 0, run.PassedCases)
				assert.Equal(t, 1, run.FailedCases)
				assert.Equal(t, 0.0, run.AccuracyRate)
				
				var details []model.EvaluationCaseResult
				err := json.Unmarshal([]byte(run.DetailsRaw), &details)
				assert.NoError(t, err)
				assert.Len(t, details, 1)
				assert.False(t, details[0].IsOverallPassed)
				assert.Contains(t, details[0].FailureReason, "Category (expected: IT, got: Facilities)")
				assert.Contains(t, details[0].FailureReason, "Urgency (expected: high, got: low)")
				assert.Contains(t, details[0].FailureReason, "SLA Risk (expected: high, got: low)")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockEvalRepo := new(testmock.MockEvaluationRepository)
			mockReportRepo := new(testmock.MockReportRepository)
			mockAdapter := new(testmock.MockTriageAdapter)

			var capturedRun *model.AIEvaluationRun

			// Register CreateRun with a .Run() interceptor first so we can capture the saved run.
			// Only tests with validateRes need this; others (error cases) never reach CreateRun.
			if tt.validateRes != nil {
				mockEvalRepo.
					On("CreateRun", mock.Anything, mock.AnythingOfType("*model.AIEvaluationRun")).
					Run(func(args mock.Arguments) {
						capturedRun = args.Get(1).(*model.AIEvaluationRun)
					}).
					Return(nil)
			}

			tt.mockRepo(mockEvalRepo, mockReportRepo)
			tt.mockAdapter(mockAdapter)

			svc := service.NewEvaluationService(mockEvalRepo, mockReportRepo, mockAdapter)
			
			req := request.AIEvaluationRequest{
				PromptVersion:     tt.promptVersion,
				EvaluationCaseIDs: tt.caseIDs,
			}

			res, err := svc.RunTriageEvaluation(context.Background(), req)

			if tt.expectedError != "" {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.expectedError)
				assert.Nil(t, res)
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, res)
				assert.Equal(t, dummyPromptVersion, res.PromptVersion)
				if tt.validateRes != nil {
					tt.validateRes(t, capturedRun)
				}
			}

			mockEvalRepo.AssertExpectations(t)
			mockReportRepo.AssertExpectations(t)
			mockAdapter.AssertExpectations(t)
		})
	}
}
