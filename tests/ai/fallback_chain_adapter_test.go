package ai_test

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/model"
)

type stubTriageAdapter struct {
	result *ai.TriageResult
	err    error
	calls  int
}

func (s *stubTriageAdapter) AnalyzeTicket(ctx context.Context, data ai.TriagePromptData) (*ai.TriageResult, error) {
	s.calls++
	return s.result, s.err
}

func (s *stubTriageAdapter) AnalyzeTicketWithVersion(ctx context.Context, data ai.TriagePromptData, promptVersion string) (*ai.TriageResult, error) {
	return s.AnalyzeTicket(ctx, data)
}

func (s *stubTriageAdapter) Model() string {
	return "stub-model"
}

func TestFallbackChainAdapter_PrimarySuccessSkipsBackup(t *testing.T) {
	primary := &stubTriageAdapter{
		result: &ai.TriageResult{
			Category:        "IT",
			ConfidenceScore: 0.9,
		},
	}
	backup := &stubTriageAdapter{
		result: &ai.TriageResult{
			Category:        "HR",
			ConfidenceScore: 0.9,
		},
	}

	result, err := ai.NewFallbackChainAdapter(primary, backup).AnalyzeTicket(context.Background(), ai.TriagePromptData{})

	require.NoError(t, err)
	assert.Equal(t, "IT", result.Category)
	assert.Equal(t, 1, primary.calls)
	assert.Equal(t, 0, backup.calls)
}

func TestFallbackChainAdapter_PrimaryErrorUsesBackup(t *testing.T) {
	primary := &stubTriageAdapter{err: errors.New("primary unavailable")}
	backup := &stubTriageAdapter{
		result: &ai.TriageResult{
			Category:        "Facilities",
			ConfidenceScore: 0.8,
		},
	}

	result, err := ai.NewFallbackChainAdapter(primary, backup).AnalyzeTicket(context.Background(), ai.TriagePromptData{})

	require.NoError(t, err)
	assert.Equal(t, "Facilities", result.Category)
	assert.Equal(t, 1, primary.calls)
	assert.Equal(t, 1, backup.calls)
}

func TestFallbackChainAdapter_PrimaryLowConfidenceSkipsBackup(t *testing.T) {
	primary := &stubTriageAdapter{
		result: &ai.TriageResult{
			Category:        "IT",
			ConfidenceScore: 0.2,
		},
	}
	backup := &stubTriageAdapter{
		result: &ai.TriageResult{
			Category:        "HR",
			ConfidenceScore: 0.75,
		},
	}

	result, err := ai.NewFallbackChainAdapter(primary, backup).AnalyzeTicket(context.Background(), ai.TriagePromptData{})

	require.NoError(t, err)
	assert.Equal(t, "IT", result.Category)
	assert.Equal(t, 0.2, result.ConfidenceScore)
	assert.Equal(t, 1, primary.calls)
	assert.Equal(t, 0, backup.calls)
}

func TestFallbackChainAdapter_MultipleFallbackModels(t *testing.T) {
	primary := &stubTriageAdapter{err: errors.New("primary timeout")}
	firstBackup := &stubTriageAdapter{
		result: &ai.TriageResult{
			Category:        "IT",
			ConfidenceScore: 0.1,
		},
	}
	secondBackup := &stubTriageAdapter{
		result: &ai.TriageResult{
			Category:        "Facilities",
			ConfidenceScore: 0.8,
		},
	}

	result, err := ai.NewFallbackChainAdapter(primary, firstBackup, secondBackup).AnalyzeTicket(context.Background(), ai.TriagePromptData{})

	require.NoError(t, err)
	assert.Equal(t, "IT", result.Category)
	assert.Equal(t, 0.1, result.ConfidenceScore)
	assert.Equal(t, 1, primary.calls)
	assert.Equal(t, 1, firstBackup.calls)
	assert.Equal(t, 0, secondBackup.calls)
}

func TestFallbackChainAdapter_LowConfidenceThenSafeDefaultApplies(t *testing.T) {
	primary := &stubTriageAdapter{
		result: &ai.TriageResult{
			Category:        "IT",
			ConfidenceScore: 0.2,
		},
	}
	backup := &stubTriageAdapter{
		result: &ai.TriageResult{
			Category:        "HR",
			ConfidenceScore: 0.9,
		},
	}
	ticket := &model.Ticket{
		ID:          1,
		Title:       "Payroll update needed",
		Description: "Employee cannot see updated payroll details.",
		Priority:    model.PriorityMedium,
	}

	result, err := ai.NewFallbackChainAdapter(primary, backup).AnalyzeTicket(
		context.Background(),
		ai.TriagePromptData{Ticket: *ticket},
	)
	finalResult := ai.ApplyFallbackIfNeeded(result, err, ticket)

	require.NoError(t, err)
	assert.True(t, finalResult.FallbackUsed)
	assert.Equal(t, "Unknown", finalResult.Category)
	assert.Equal(t, "fallback", finalResult.PromptVersion)
	assert.Equal(t, 1, primary.calls)
	assert.Equal(t, 0, backup.calls)
}

func TestFallbackChainAdapter_BothModelsFailThenSafeDefaultApplies(t *testing.T) {
	primary := &stubTriageAdapter{err: errors.New("primary rate limited")}
	backup := &stubTriageAdapter{err: errors.New("backup timeout")}
	ticket := &model.Ticket{
		ID:          1,
		Title:       "Payroll update needed",
		Description: "Employee cannot see updated payroll details.",
		Priority:    model.PriorityMedium,
	}

	result, err := ai.NewFallbackChainAdapter(primary, backup).AnalyzeTicket(
		context.Background(),
		ai.TriagePromptData{Ticket: *ticket},
	)
	finalResult := ai.ApplyFallbackIfNeeded(result, err, ticket)

	require.Error(t, err)
	assert.True(t, finalResult.FallbackUsed)
	assert.Equal(t, "Unknown", finalResult.Category)
	assert.Equal(t, "fallback", finalResult.PromptVersion)
	assert.Equal(t, 1, primary.calls)
	assert.Equal(t, 1, backup.calls)
}
