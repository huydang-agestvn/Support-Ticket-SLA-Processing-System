package service

import (
	"regexp"

	"support-ticket.com/internal/safetyrule"
)

const (
	ContentSafetyCategoryProfanity = safetyrule.CategoryProfanity
	ContentSafetyCategoryInsult    = safetyrule.CategoryInsult
	ContentSafetyCategorySpam      = safetyrule.CategorySpam
	ContentSafetyCategoryGibberish = safetyrule.CategoryGibberish
)

type ContentSafetyResult struct {
	Blocked     bool    `json:"blocked"`
	Flagged     bool    `json:"flagged"`
	Score       float64 `json:"score,omitempty"`
	Category    string  `json:"category,omitempty"`
	Reason      string  `json:"reason,omitempty"`
	MatchedRule string  `json:"matched_rule,omitempty"`
}

type ContentSafetyService interface {
	CheckTicket(title, description string) ContentSafetyResult
}

type ruleBasedContentSafetyService struct {
	rules []safetyrule.Rule
}

func NewContentSafetyService() ContentSafetyService {
	return &ruleBasedContentSafetyService{
		rules: safetyrule.Rules,
	}
}

func (s *ruleBasedContentSafetyService) CheckTicket(title, description string) ContentSafetyResult {
	reps := safetyrule.BuildSafetyTextRepresentations(title, description)

	if result, blocked := s.matchRules(reps); blocked {
		return result
	}

	for _, fieldReps := range []safetyrule.SafetyTextRepresentations{
		safetyrule.BuildSafetyTextRepresentations(title, ""),
		safetyrule.BuildSafetyTextRepresentations("", description),
	} {
		if fieldReps.IsEmpty() {
			continue
		}
		if match, blocked := safetyrule.DetectGibberish(fieldReps.Raw, fieldReps.FoldedNormalized); blocked {
			return blockedContent(match.Category, match.Name, match.Reason)
		}
	}

	if match, blocked := safetyrule.DetectGibberish(reps.Raw, reps.FoldedNormalized); blocked {
		return blockedContent(match.Category, match.Name, match.Reason)
	}
	if result, blocked := detectSpam(reps.Raw, reps.Normalized); blocked {
		return result
	}

	return ContentSafetyResult{}
}

func (s *ruleBasedContentSafetyService) matchRules(reps safetyrule.SafetyTextRepresentations) (ContentSafetyResult, bool) {
	for _, rule := range s.rules {
		if rule.Pattern.MatchString(ruleInput(rule.MatchInput, reps)) {
			return blockedContent(rule.Category, rule.Name, rule.Reason), true
		}
	}
	return ContentSafetyResult{}, false
}

func ruleInput(input safetyrule.MatchInput, reps safetyrule.SafetyTextRepresentations) string {
	switch input {
	case safetyrule.MatchUnicode:
		return reps.Unicode
	case safetyrule.MatchObfuscated:
		return reps.Obfuscated
	default:
		return reps.Normalized
	}
}

func detectSpam(raw, normalized string) (ContentSafetyResult, bool) {
	if countMatches(raw, safetyrule.URLPattern) > safetyrule.MaxAllowedURLs {
		return blockedContent(ContentSafetyCategorySpam, "excessive_urls", "ticket contains excessive links"), true
	}
	if countMatches(raw, safetyrule.EmailPattern) > safetyrule.MaxAllowedEmails {
		return blockedContent(ContentSafetyCategorySpam, "excessive_email_addresses", "ticket contains excessive email addresses"), true
	}
	if safetyrule.PromoPattern.MatchString(normalized) {
		return blockedContent(ContentSafetyCategorySpam, "promotional_phrase", "ticket contains promotional spam language"), true
	}
	return ContentSafetyResult{}, false
}

func blockedContent(category, rule, reason string) ContentSafetyResult {
	return ContentSafetyResult{
		Blocked:     true,
		Category:    category,
		Reason:      reason,
		MatchedRule: rule,
	}
}

func countMatches(text string, pattern *regexp.Regexp) int {
	return len(pattern.FindAllString(text, -1))
}
