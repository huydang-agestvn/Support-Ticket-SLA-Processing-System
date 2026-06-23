package service

import (
	"regexp"
	"strings"
	"unicode"

	"golang.org/x/text/unicode/norm"
)

const (
	ContentSafetyCategoryProfanity = "profanity"
	ContentSafetyCategoryInsult    = "insult"
	ContentSafetyCategorySpam      = "spam"
	ContentSafetyCategoryGibberish = "gibberish"

	maxAllowedURLs   = 5
	maxAllowedEmails = 5
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
	rules []contentSafetyRule
}

type contentSafetyMatchInput string

const (
	contentSafetyMatchNormalized contentSafetyMatchInput = "normalized"
	contentSafetyMatchObfuscated contentSafetyMatchInput = "obfuscated"
	contentSafetyMatchUnicode    contentSafetyMatchInput = "unicode"
)

type contentSafetyRule struct {
	Name       string
	Pattern    *regexp.Regexp
	Category   string
	Reason     string
	MatchInput contentSafetyMatchInput
}

type safetyTextRepresentations struct {
	Raw        string
	Unicode    string
	Normalized string
	Obfuscated string
}

var contentSafetyRules = []contentSafetyRule{
	groupedSafetyRule("direct_common_profanity", ContentSafetyCategoryProfanity, "ticket contains inappropriate language", contentSafetyMatchObfuscated, `fuck(?:ing|in)?`, `motherfucker`, `shit(?:ty)?`, `bullshit`, `asshole`, `bastard`, `bitch(?:es)?`, `cunt`, `twat`, `wank(?:er)?`),
	groupedSafetyRule("direct_common_insult", ContentSafetyCategoryInsult, "ticket contains direct insulting language", contentSafetyMatchObfuscated, `idiot`, `st[ou]+pid`, `moron`, `dumb`, `jerk`, `loser`),
	groupedSafetyRule("contextual_trash_insult", ContentSafetyCategoryInsult, "ticket contains direct insulting language", contentSafetyMatchObfuscated, `(?:you|u)\s+(?:are|r)\s+trash`, `(?:this|that|your|ur)\s+(?:team|service|support|ticket)\s+(?:is|r)\s+trash`),
	groupedSafetyRule("obfuscated_common_profanity", ContentSafetyCategoryProfanity, "ticket contains obfuscated inappropriate language", contentSafetyMatchUnicode, obfuscatedWordPattern("fuck"), obfuscatedWordPattern("shit"), obfuscatedWordPattern("bitch"), obfuscatedWordPattern("cunt")),
	groupedSafetyRule("obfuscated_common_insult", ContentSafetyCategoryInsult, "ticket contains obfuscated insulting language", contentSafetyMatchUnicode, obfuscatedWordPattern("idiot"), `st[\s._*\-]*[ou]+[\s._*\-]*p[\s._*\-]*i[\s._*\-]*d`, obfuscatedWordPattern("moron")),
	groupedSafetyRule("gambling_spam", ContentSafetyCategorySpam, "ticket contains gambling promotional content", contentSafetyMatchNormalized, `casino promotion`, `place a bet`, `betting promotion`, `gambling promotion`),
	groupedSafetyRule("adult_content_spam", ContentSafetyCategorySpam, "ticket contains adult promotional content", contentSafetyMatchNormalized, `porn links`, `free porn`, `adult links`, `xxx links`, `nsfw links`),
	groupedSafetyRule("illegal_drug_spam", ContentSafetyCategorySpam, "ticket contains illegal drug promotional content", contentSafetyMatchNormalized, `buy illegal drugs`, `illegal drugs from`, `buy cocaine`, `buy heroin`),
}

var (
	contentSafetyURLPattern   = regexp.MustCompile(`(?i)https?://|www\.`)
	contentSafetyEmailPattern = regexp.MustCompile(`(?i)[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}`)
	contentSafetyPromoPattern = regexp.MustCompile(`\b(buy now|limited offer|free money)\b`)
)

func NewContentSafetyService() ContentSafetyService {
	return &ruleBasedContentSafetyService{
		rules: contentSafetyRules,
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

func groupedSafetyRule(name, category, reason string, input contentSafetyMatchInput, alternatives ...string) contentSafetyRule {
	return contentSafetyRule{
		Name:       name,
		Pattern:    regexp.MustCompile(`\b(?:` + strings.Join(alternatives, "|") + `)\b`),
		Category:   category,
		Reason:     reason,
		MatchInput: input,
	}
}

func obfuscatedWordPattern(word string) string {
	parts := make([]string, 0, len(word))
	for _, r := range word {
		parts = append(parts, regexp.QuoteMeta(string(r)))
	}
	return strings.Join(parts, `[\s._*\-]*`)
}

func (s *ruleBasedContentSafetyService) matchRules(reps safetyTextRepresentations) (ContentSafetyResult, bool) {
	for _, rule := range s.rules {
		if rule.Pattern.MatchString(ruleInput(rule.MatchInput, reps)) {
			return blockedContent(rule.Category, rule.Name, rule.Reason), true
		}
	}
	return ContentSafetyResult{}, false
}

func ruleInput(input contentSafetyMatchInput, reps safetyTextRepresentations) string {
	switch input {
	case contentSafetyMatchUnicode:
		return reps.Unicode
	case contentSafetyMatchObfuscated:
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
	if countMatches(raw, contentSafetyURLPattern) > maxAllowedURLs {
		return blockedContent(ContentSafetyCategorySpam, "excessive_urls", "ticket contains excessive links"), true
	}
	if countMatches(raw, contentSafetyEmailPattern) > maxAllowedEmails {
		return blockedContent(ContentSafetyCategorySpam, "excessive_email_addresses", "ticket contains excessive email addresses"), true
	}
	if contentSafetyPromoPattern.MatchString(normalized) {
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
