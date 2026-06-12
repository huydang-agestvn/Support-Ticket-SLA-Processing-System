package ai

import (
	"fmt"
	"regexp"
	"strings"
	"time"

	"support-ticket.com/internal/model"
)

const confidenceThreshold = 0.5

func ApplyFallbackIfNeeded(result *TriageResult, err error, ticket *model.Ticket) *TriageResult {
	if err != nil || result == nil || result.ConfidenceScore < confidenceThreshold {
		return buildFallbackResult(ticket, result)
	}
	return result
}

func buildFallbackResult(ticket *model.Ticket, result *TriageResult) *TriageResult {
	now := time.Now()

	slaBreachRisk := "low"
	if ticket.SLADueAt != nil {
		totalWindow := ticket.SLADueAt.Sub(ticket.CreatedAt)
		timeLeft := ticket.SLADueAt.Sub(now)

		if totalWindow > 0 {
			percentLeft := float64(timeLeft) / float64(totalWindow)
			if percentLeft < 0.0 || now.After(*ticket.SLADueAt) {
				slaBreachRisk = "high"
			} else if percentLeft <= 0.20 {
				// Less than 20% of the original time remaining
				slaBreachRisk = "high"
			} else if percentLeft <= 0.50 {
				// Less than 50% of the original time remaining
				slaBreachRisk = "medium"
			}
		} else if now.After(*ticket.SLADueAt) {
			slaBreachRisk = "high"
		}
	}

	textToAnalyze := strings.ToLower(ticket.Title + " " + ticket.Description)
	category := "IT"

	hrRegex := regexp.MustCompile(`\b(salary|payroll|leave|contract|benefits|onboarding|insurance)\b`)
	facilitiesRegex := regexp.MustCompile(`\b(light|aircon|ac|chair|table|desk|door|leak|office|building)\b`)

	if hrRegex.MatchString(textToAnalyze) {
		category = "HR"
	} else if facilitiesRegex.MatchString(textToAnalyze) {
		category = "Facilities"
	}

	reasonParts := []string{"Fallback: AI unavailable or low confidence."}
	if category != "IT" {
		reasonParts = append(reasonParts, fmt.Sprintf("Category mapped to %s via keyword matching.", category))
	} else {
		reasonParts = append(reasonParts, "Category defaulted to IT (no specific keywords found).")
	}

	switch slaBreachRisk {
	case "high":
		reasonParts = append(reasonParts, "SLA Risk is HIGH because the ticket is either overdue or has less than 20% of its SLA window remaining.")
	case "medium":
		reasonParts = append(reasonParts, "SLA Risk is MEDIUM because the ticket has less than 50% of its SLA window remaining.")
	default:
		reasonParts = append(reasonParts, "SLA Risk is LOW because there is still plenty of time.")
	}

	confidenceScore := 0.0
	if result != nil {
		confidenceScore = result.ConfidenceScore
	}

	return &TriageResult{
		Category:              category,
		UrgencyLevel:          string(ticket.Priority),
		SLABreachRisk:         slaBreachRisk,
		ReasonSummary:         strings.Join(reasonParts, " "),
		RecommendedNextAction: "Review ticket manually and verify category and urgency.",
		ConfidenceScore:       confidenceScore,
		FallbackUsed:          true,
		PromptVersion:         "fallback",
	}
}
