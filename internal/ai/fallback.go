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
	category := "General Support"

	if strings.Contains(textToAnalyze, "network") || strings.Contains(textToAnalyze, "wifi") || strings.Contains(textToAnalyze, "internet") || strings.Contains(textToAnalyze, "connection") {
		category = "Network/Infrastructure"
	} else if strings.Contains(textToAnalyze, "password") || strings.Contains(textToAnalyze, "account") || strings.Contains(textToAnalyze, "login") || strings.Contains(textToAnalyze, "access") {
		category = "Access/Authentication"
	} else if strings.Contains(textToAnalyze, "hardware") || strings.Contains(textToAnalyze, "mouse") || strings.Contains(textToAnalyze, "monitor") || strings.Contains(textToAnalyze, "printer") {
		category = "Hardware"
	} else if strings.Contains(textToAnalyze, "software") || strings.Contains(textToAnalyze, "install") || strings.Contains(textToAnalyze, "app") || strings.Contains(textToAnalyze, "crash") {
		category = "Software"
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