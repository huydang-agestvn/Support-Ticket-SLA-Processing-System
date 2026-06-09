package ai

import (
    "context"
    "support-ticket.com/internal/dto/request"
    "support-ticket.com/internal/dto/response"
)

type FakeAdapter struct {
    promptVersion string
}

func NewFakeAdapter(promptVersion string) *FakeAdapter {
    return &FakeAdapter{promptVersion: promptVersion}
}

func (f *FakeAdapter) Triage(_ context.Context, _ request.TriageRequest) (*response.TriageResponse, error) {
    return &response.TriageResponse{
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