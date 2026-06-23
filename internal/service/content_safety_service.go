package service

import (
	"regexp"
	"strings"
	"unicode"

	"golang.org/x/text/unicode/norm"
	"support-ticket.com/internal/safetyrule"
)

const (
	ContentSafetyCategoryProfanity = safetyrule.CategoryProfanity
	ContentSafetyCategoryInsult    = safetyrule.CategoryInsult
	ContentSafetyCategorySpam      = safetyrule.CategorySpam
	ContentSafetyCategoryGibberish = safetyrule.CategoryGibberish
)

type ContentSafetyResult struct {
	Blocked     bool   `json:"blocked"`
	Category    string `json:"category,omitempty"`
	Reason      string `json:"reason,omitempty"`
	MatchedRule string `json:"matched_rule,omitempty"`
}

type ContentSafetyService interface {
	CheckTicket(title, description string) ContentSafetyResult
}

type ruleBasedContentSafetyService struct {
	rules []safetyrule.Rule
}

type safetyTextRepresentations struct {
	Raw        string
	Unicode    string
	Normalized string
	Obfuscated string
}

func NewContentSafetyService() ContentSafetyService {
	return &ruleBasedContentSafetyService{
		rules: safetyrule.Rules,
	}
}

func (s *ruleBasedContentSafetyService) CheckTicket(title, description string) ContentSafetyResult {
	reps := buildSafetyTextRepresentations(title, description)

	if result, blocked := s.matchRules(reps); blocked {
		return result
	}
	if result, blocked := detectGibberish(reps.Raw, reps.Normalized); blocked {
		return result
	}
	if result, blocked := detectSpam(reps.Raw, reps.Normalized); blocked {
		return result
	}

	return ContentSafetyResult{}
}

func (s *ruleBasedContentSafetyService) matchRules(reps safetyTextRepresentations) (ContentSafetyResult, bool) {
	for _, rule := range s.rules {
		if rule.Pattern.MatchString(ruleInput(rule.MatchInput, reps)) {
			return blockedContent(rule.Category, rule.Name, rule.Reason), true
		}
	}
	return ContentSafetyResult{}, false
}

func ruleInput(input safetyrule.MatchInput, reps safetyTextRepresentations) string {
	switch input {
	case safetyrule.MatchUnicode:
		return reps.Unicode
	case safetyrule.MatchObfuscated:
		return reps.Obfuscated
	default:
		return reps.Normalized
	}
}

func buildSafetyTextRepresentations(title, description string) safetyTextRepresentations {
	raw := strings.TrimSpace(title + " " + description)
	unicodeText := strings.ToLower(removeZeroWidthCharacters(norm.NFKC.String(raw)))
	normalized := normalizeSafetyText(unicodeText)

	return safetyTextRepresentations{
		Raw:        raw,
		Unicode:    unicodeText,
		Normalized: normalized,
		Obfuscated: normalizeLeetTokens(normalized),
	}
}

func removeZeroWidthCharacters(input string) string {
	return strings.Map(func(r rune) rune {
		switch r {
		case '\u200B', '\u200C', '\u200D', '\uFEFF':
			return -1
		default:
			return r
		}
	}, input)
}

func normalizeSafetyText(input string) string {
	var b strings.Builder
	b.Grow(len(input))

	lastWasSpace := false
	for _, r := range input {
		switch {
		case unicode.IsLetter(r), unicode.IsDigit(r):
			b.WriteRune(r)
			lastWasSpace = false
		case unicode.IsSpace(r):
			if !lastWasSpace {
				b.WriteByte(' ')
				lastWasSpace = true
			}
		default:
			if !lastWasSpace {
				b.WriteByte(' ')
				lastWasSpace = true
			}
		}
	}

	return strings.TrimSpace(b.String())
}

func normalizeLeetTokens(normalized string) string {
	words := strings.Fields(normalized)
	for i, word := range words {
		if isSuspiciousLeetToken(word) {
			words[i] = replaceLeetRunes(word)
		}
	}
	return strings.Join(words, " ")
}

func isSuspiciousLeetToken(word string) bool {
	hasLetter := false
	hasLeet := false
	for _, r := range word {
		if unicode.IsLetter(r) {
			hasLetter = true
		}
		if strings.ContainsRune("013457", r) {
			hasLeet = true
		}
	}
	return hasLetter && hasLeet
}

func replaceLeetRunes(word string) string {
	var b strings.Builder
	b.Grow(len(word))
	for _, r := range word {
		switch r {
		case '0':
			b.WriteByte('o')
		case '1':
			b.WriteByte('i')
		case '3':
			b.WriteByte('e')
		case '4':
			b.WriteByte('a')
		case '5':
			b.WriteByte('s')
		case '7':
			b.WriteByte('t')
		default:
			b.WriteRune(r)
		}
	}
	return b.String()
}

func detectGibberish(raw, normalized string) (ContentSafetyResult, bool) {
	letters, digits, symbols := countSafetyTextClasses(raw)
	total := letters + digits + symbols
	if total > 0 && symbols >= 10 && float64(symbols)/float64(total) >= 0.70 {
		return blockedContent(ContentSafetyCategoryGibberish, "symbol_heavy_content", "ticket content is mostly symbols"), true
	}

	words := meaningfulWords(normalized)
	if len(words) == 0 {
		return ContentSafetyResult{}, false
	}

	if len(words) == 1 && hasRepeatedRun(words[0], 6, unicode.IsLetter) {
		return blockedContent(ContentSafetyCategoryGibberish, "repeated_characters", "ticket content contains repeated characters"), true
	}
	if hasRepeatedRun(normalized, 12, unicode.IsLetter) || hasRepeatedRun(raw, 10, isPunctuation) {
		return blockedContent(ContentSafetyCategoryGibberish, "repeated_characters", "ticket content contains repeated characters"), true
	}
	if len(words) >= 6 && mostRepeatedWordRatio(words) >= 0.80 {
		return blockedContent(ContentSafetyCategoryGibberish, "repeated_words", "ticket content repeats the same words"), true
	}
	if looksLikeRepeatedNonsense(words) {
		return blockedContent(ContentSafetyCategoryGibberish, "repeated_nonsense", "ticket content appears to be meaningless repetition"), true
	}

	return ContentSafetyResult{}, false
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

func countSafetyTextClasses(text string) (letters, digits, symbols int) {
	for _, r := range text {
		switch {
		case unicode.IsLetter(r):
			letters++
		case unicode.IsDigit(r):
			digits++
		case unicode.IsSpace(r):
		default:
			symbols++
		}
	}
	return letters, digits, symbols
}

func countLetters(text string) int {
	count := 0
	for _, r := range text {
		if unicode.IsLetter(r) {
			count++
		}
	}
	return count
}

func meaningfulWords(normalized string) []string {
	rawWords := strings.Fields(normalized)
	words := make([]string, 0, len(rawWords))
	for _, word := range rawWords {
		if countLetters(word) >= 2 {
			words = append(words, word)
		}
	}
	return words
}

func hasRepeatedRun(text string, threshold int, include func(rune) bool) bool {
	var last rune
	runLength := 0
	for _, r := range text {
		if !include(r) {
			last = 0
			runLength = 0
			continue
		}
		if r == last {
			runLength++
		} else {
			last = r
			runLength = 1
		}
		if runLength >= threshold {
			return true
		}
	}
	return false
}

func isPunctuation(r rune) bool {
	return !unicode.IsLetter(r) && !unicode.IsDigit(r) && !unicode.IsSpace(r)
}

func mostRepeatedWordRatio(words []string) float64 {
	if len(words) == 0 {
		return 0
	}
	counts := make(map[string]int, len(words))
	maxCount := 0
	for _, word := range words {
		counts[word]++
		if counts[word] > maxCount {
			maxCount = counts[word]
		}
	}
	return float64(maxCount) / float64(len(words))
}

func looksLikeRepeatedNonsense(words []string) bool {
	if len(words) == 0 {
		return false
	}
	for _, word := range words {
		runes := []rune(word)
		if len(runes) < 12 || len(runes)%2 != 0 {
			continue
		}
		half := len(runes) / 2
		if string(runes[:half]) == string(runes[half:]) {
			return true
		}
	}
	return false
}

func countMatches(text string, pattern *regexp.Regexp) int {
	return len(pattern.FindAllString(text, -1))
}
