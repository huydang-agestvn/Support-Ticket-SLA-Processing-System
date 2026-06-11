package ai

import (
	"strings"
	"time"

	"support-ticket.com/internal/model"
)

const confidenceThreshold = 0.5

func ApplyFallbackIfNeeded(result *TriageResult, err error, ticket *model.Ticket) *TriageResult {
	if err != nil || result == nil || result.ConfidenceScore < confidenceThreshold {
		return buildFallbackResult(ticket)
	}
	return result
}

func buildFallbackResult(ticket *model.Ticket) *TriageResult {
	now := time.Now().UTC()

	slaBreachRisk := "low"
	if ticket.SLADueAt != nil {
		timeLeft := ticket.SLADueAt.Sub(now)
		if now.After(*ticket.SLADueAt) {
			slaBreachRisk = "high"
		} else if timeLeft < 2*time.Hour {
			slaBreachRisk = "medium"
		}
	}

	textToAnalyze := strings.ToLower(ticket.Title + " " + ticket.Description)
	category := "IT"

	if strings.Contains(textToAnalyze, "salary") || strings.Contains(textToAnalyze, "payroll") || strings.Contains(textToAnalyze, "leave") || strings.Contains(textToAnalyze, "contract") || strings.Contains(textToAnalyze, "benefits") || strings.Contains(textToAnalyze, "onboarding") || strings.Contains(textToAnalyze, "insurance") {
		category = "HR"
	} else if strings.Contains(textToAnalyze, "light") || strings.Contains(textToAnalyze, "aircon") || strings.Contains(textToAnalyze, "ac") || strings.Contains(textToAnalyze, "chair") || strings.Contains(textToAnalyze, "table") || strings.Contains(textToAnalyze, "desk") || strings.Contains(textToAnalyze, "door") || strings.Contains(textToAnalyze, "leak") || strings.Contains(textToAnalyze, "office") || strings.Contains(textToAnalyze, "building") {
		category = "Facilities"
	}

	return &TriageResult{
		Category:              category,
		UrgencyLevel:          string(ticket.Priority),
		SLABreachRisk:         slaBreachRisk,
		ReasonSummary:         "Fallback: AI unavailable or low confidence. Category mapped by keywords and SLA risk calculated deterministically.",
		RecommendedNextAction: "Review ticket manually and verify category/urgency.",
		ConfidenceScore:       0.0,
		FallbackUsed:          true,
		PromptVersion:         "fallback",
	}
}