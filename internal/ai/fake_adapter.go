package ai

import "context"

type FakeAdapter struct {
	promptVersion string
}

func NewFakeAdapter(promptVersion string) *FakeAdapter {
	return &FakeAdapter{promptVersion: promptVersion}
}

func (f *FakeAdapter) Triage(_ context.Context, _ TriageRequest) (*TriageResponse, error) {
	return &TriageResponse{
		Category:              "Facility",
		UrgencyLevel:          "high",
		SLABreachRisk:         "medium",
		ReasonSummary:         "Ticket contains indicators of a recurring technical issue with unclear ownership.",
		RecommendedNextAction: "Assign to Level 2 support and verify SLA deadline.",
		ConfidenceScore:       0.85,
		FallbackUsed:          false,
		PromptVersion:         f.promptVersion,
	}, nil
}