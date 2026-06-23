package service_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/config"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/service"
	testmock "support-ticket.com/tests/mock"
)

func TestExecuteTriage_RuleEngine_ShortCircuit_Success(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, &config.Config{})

	// Mock active rule patterns
	mockTriageRepo.On("GetActiveRulePatterns", mock.Anything).Return([]response.RulePatternResponse{
		{
			ID:                1,
			SubDepartmentCode: "IT001",
			Pattern:           `(?i)fatal database error|server crash`,
			PatternType:       "regex",
			Priority:          "high",
			IsActive:          true,
			Name:              "Hardware Inventory & Equipment Provisioning",
			Floor:             "Floor 18",
			Description:       "Handles physical hardware equipment for employees...",
		},
	}, nil)

	futureTime := time.Now().Add(4 * time.Hour)
	ticket := &model.Ticket{
		ID:          101,
		Title:       "Fatal database error detected",
		Description: "The production server crash occurred just now.",
		Status:      model.StatusNew,
		Priority:    model.PriorityHigh,
		Category:    model.CategoryIT,
		SLADueAt:    &futureTime,
		AuditModel: model.AuditModel{
			CreatedAt: time.Now(),
		},
	}

	// 1. Mock DB fetching for ticket details
	mockTicketRepo.On("FindById", mock.Anything, uint(101)).Return(ticket, nil)

	// 2. Mock Report fetching
	mockReportRepo.On("GetByDate", mock.Anything).Return(&model.TicketReport{}, nil)

	// 3. Mock Triage Repository Create to check it saves the AITicketTriageResult
	mockTriageRepo.On("Create", mock.Anything, mock.MatchedBy(func(res *model.AITicketTriageResult) bool {
		return res.TicketID == 101 &&
			res.Category == "IT" &&
			res.UrgencyLevel == "high" &&
			res.ConfidenceScore == 1.0 &&
			!res.FallbackUsed &&
			res.PromptVersion == "rule_engine_v1.0"
	})).Return(nil)

	// Notice: we do NOT mock any calls on mockAI, because the AI adapter should be short-circuited!

	res, err := svc.ExecuteTriage(context.Background(), 101)

	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Equal(t, "IT", res.Category)
	assert.Equal(t, "high", res.UrgencyLevel)
	assert.Equal(t, 1.0, res.ConfidenceScore)
	assert.False(t, res.FallbackUsed)
	assert.Contains(t, res.ReasonSummary, "automatically escalated to high urgency by the System Rule Engine")

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertExpectations(t)
	mockTriageRepo.AssertExpectations(t)
	mockAI.AssertExpectations(t) // Verifies mockAI.AnalyzeTicket was never called!
}

func TestExecuteTriage_RuleEngine_NoMatch(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, &config.Config{})

	// Mock active rule patterns
	mockTriageRepo.On("GetActiveRulePatterns", mock.Anything).Return([]response.RulePatternResponse{
		{
			ID:                1,
			SubDepartmentCode: "IT001",
			Pattern:           `(?i)fatal database error`,
			PatternType:       "regex",
			Priority:          "high",
			IsActive:          true,
			Name:              "Hardware Inventory & Equipment Provisioning",
			Floor:             "Floor 18",
			Description:       "Handles physical hardware equipment for employees...",
		},
	}, nil)

	futureTime := time.Now().Add(4 * time.Hour)
	ticket := &model.Ticket{
		ID:          102,
		Title:       "Low priority query",
		Description: "I have a small request about internal system access.",
		Status:      model.StatusNew,
		Priority:    model.PriorityLow,
		Category:    model.CategoryIT,
		SLADueAt:    &futureTime,
		AuditModel: model.AuditModel{
			CreatedAt: time.Now(),
		},
	}

	// 1. Mock DB fetching for ticket details
	mockTicketRepo.On("FindById", mock.Anything, uint(102)).Return(ticket, nil)

	// 2. Mock Report fetching
	mockReportRepo.On("GetByDate", mock.Anything).Return(&model.TicketReport{}, nil)

	// 3. Since there's no match, the rule engine passes through. We MUST mock the AI adapter!
	mockAI.On("AnalyzeTicket", mock.Anything, mock.Anything).Return(&ai.TriageResult{
		Category:              "IT",
		UrgencyLevel:          "low",
		SLABreachRisk:         "low",
		ReasonSummary:         "Simple system query",
		RecommendedNextAction: "Provide documentation",
		ConfidenceScore:       0.8,
		FallbackUsed:          false,
		PromptVersion:         "v1.1",
	}, nil)

	// 4. Mock Triage Repository Create for the AI result
	mockTriageRepo.On("Create", mock.Anything, mock.Anything).Return(nil)

	res, err := svc.ExecuteTriage(context.Background(), 102)

	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Equal(t, "IT", res.Category)
	assert.Equal(t, "low", res.UrgencyLevel)
	assert.Equal(t, 0.8, res.ConfidenceScore)

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertExpectations(t)
	mockTriageRepo.AssertExpectations(t)
	mockAI.AssertExpectations(t)
}

func TestExecuteTriage_RuleEngine_CategoryMismatch_Override(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, &config.Config{})

	// Mock active rule patterns
	mockTriageRepo.On("GetActiveRulePatterns", mock.Anything).Return([]response.RulePatternResponse{
		{
			ID:                1,
			SubDepartmentCode: "FC001",
			Pattern:           `(?i)electrical fire|flooding`,
			PatternType:       "regex",
			Priority:          "high",
			IsActive:          true,
			Name:              "Workplace & Utilities",
			Floor:             "Floor 2",
			Description:       "Handles facility repairs, electrical issues, etc.",
		},
	}, nil)

	futureTime := time.Now().Add(4 * time.Hour)
	ticket := &model.Ticket{
		ID:          103,
		Title:       "Facilities Emergency!",
		Description: "There is an electrical fire in the hallway.",
		Status:      model.StatusNew,
		Priority:    model.PriorityHigh,
		Category:    model.CategoryIT, // Wrong input category
		SLADueAt:    &futureTime,
		AuditModel: model.AuditModel{
			CreatedAt: time.Now(),
		},
	}

	// 1. Mock DB fetching for ticket details
	mockTicketRepo.On("FindById", mock.Anything, uint(103)).Return(ticket, nil)

	// 2. Mock Report fetching
	mockReportRepo.On("GetByDate", mock.Anything).Return(&model.TicketReport{}, nil)

	// 3. Mock ticket repository UpdateCategory
	mockTicketRepo.On("UpdateCategory", mock.Anything, uint(103), model.CategoryFacilities).Return(nil)

	// 4. Mock Triage Repository Create to check it saves the overridden result
	mockTriageRepo.On("Create", mock.Anything, mock.MatchedBy(func(res *model.AITicketTriageResult) bool {
		return res.TicketID == 103 &&
			res.Category == "Facilities" &&
			res.UrgencyLevel == "high" &&
			res.ConfidenceScore == 1.0 &&
			!res.FallbackUsed &&
			res.PromptVersion == "rule_engine_v1.0"
	})).Return(nil)

	res, err := svc.ExecuteTriage(context.Background(), 103)

	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Equal(t, "Facilities", res.Category)
	assert.Equal(t, "high", res.UrgencyLevel)
	assert.Contains(t, res.ReasonSummary, "detected a critical input mismatch")
	assert.Contains(t, res.ReasonSummary, "User selected 'IT', but content matched 'Facilities'")

	// Wait briefly for asynchronous goroutine to trigger mock call
	time.Sleep(100 * time.Millisecond)

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertExpectations(t)
	mockTriageRepo.AssertExpectations(t)
	mockAI.AssertExpectations(t)
}

func TestExecuteTriage_RuleEngine_ShortCircuit_MediumPriority(t *testing.T) {
	mockTicketRepo := new(testmock.MockTicketRepository)
	mockReportRepo := new(testmock.MockReportRepository)
	mockTriageRepo := new(testmock.MockTriageRepository)
	mockAI := new(mockAIAdapter)

	svc := service.NewTriageService(mockTicketRepo, mockReportRepo, mockTriageRepo, mockAI, &config.Config{})

	// Mock active rule patterns (returning a medium priority rule)
	mockTriageRepo.On("GetActiveRulePatterns", mock.Anything).Return([]response.RulePatternResponse{
		{
			ID:                1,
			SubDepartmentCode: "IT001",
			Pattern:           `(?i)fatal database error|server crash`,
			PatternType:       "regex",
			Priority:          "medium",
			IsActive:          true,
			Name:              "Hardware Inventory & Equipment Provisioning",
			Floor:             "Floor 18",
			Description:       "Handles physical hardware equipment for employees...",
		},
	}, nil)

	futureTime := time.Now().Add(4 * time.Hour)
	ticket := &model.Ticket{
		ID:          104,
		Title:       "Fatal database error detected",
		Description: "The production server crash occurred just now.",
		Status:      model.StatusNew,
		Priority:    model.PriorityHigh,
		Category:    model.CategoryIT,
		SLADueAt:    &futureTime,
		AuditModel: model.AuditModel{
			CreatedAt: time.Now(),
		},
	}

	// 1. Mock DB fetching for ticket details
	mockTicketRepo.On("FindById", mock.Anything, uint(104)).Return(ticket, nil)

	// 2. Mock Report fetching
	mockReportRepo.On("GetByDate", mock.Anything).Return(&model.TicketReport{}, nil)

	// 3. Mock Triage Repository Create to check it saves the AITicketTriageResult with "medium" urgency
	mockTriageRepo.On("Create", mock.Anything, mock.MatchedBy(func(res *model.AITicketTriageResult) bool {
		return res.TicketID == 104 &&
			res.Category == "IT" &&
			res.UrgencyLevel == "medium" &&
			res.ConfidenceScore == 1.0 &&
			!res.FallbackUsed &&
			res.PromptVersion == "rule_engine_v1.0"
	})).Return(nil)

	res, err := svc.ExecuteTriage(context.Background(), 104)

	assert.NoError(t, err)
	assert.NotNil(t, res)
	assert.Equal(t, "IT", res.Category)
	assert.Equal(t, "medium", res.UrgencyLevel)
	assert.Equal(t, 1.0, res.ConfidenceScore)
	assert.False(t, res.FallbackUsed)

	mockTicketRepo.AssertExpectations(t)
	mockReportRepo.AssertExpectations(t)
	mockTriageRepo.AssertExpectations(t)
	mockAI.AssertExpectations(t)
}
