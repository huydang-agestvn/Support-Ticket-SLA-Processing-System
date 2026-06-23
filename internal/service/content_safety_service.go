package service

import (
	"regexp"
	"strings"
	"unicode"

	"golang.org/x/text/transform"
	"golang.org/x/text/unicode/norm"
	"support-ticket.com/internal/safetyrule"
)

const (
	ContentSafetyCategoryProfanity = safetyrule.CategoryProfanity
	ContentSafetyCategoryInsult    = safetyrule.CategoryInsult
	ContentSafetyCategorySpam      = safetyrule.CategorySpam
	ContentSafetyCategoryGibberish = safetyrule.CategoryGibberish

	minBigramGibberishWordLength = 20
	maxRareBigramRatio           = 0.45
	maxConsecutiveRareBigrams    = 4
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
	Raw              string
	Unicode          string
	Normalized       string
	FoldedNormalized string
	Obfuscated       string
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
	for _, fieldReps := range []safetyTextRepresentations{
		buildSafetyTextRepresentations(title, ""),
		buildSafetyTextRepresentations("", description),
	} {
		if strings.TrimSpace(fieldReps.Raw) == "" {
			continue
		}
		if result, blocked := detectGibberish(fieldReps.Raw, fieldReps.FoldedNormalized); blocked {
			return result
		}
	}
	if result, blocked := detectGibberish(reps.Raw, reps.FoldedNormalized); blocked {
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
	foldedText := foldLatinText(unicodeText)
	foldedNormalized := normalizeSafetyText(foldedText)
	symbolLeetNormalized := normalizeSafetyText(replaceSymbolLeetInsideWords(unicodeText))

	return safetyTextRepresentations{
		Raw:              raw,
		Unicode:          unicodeText,
		Normalized:       normalized,
		FoldedNormalized: foldedNormalized,
		Obfuscated:       normalizeLeetTokens(symbolLeetNormalized),
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

func foldLatinText(input string) string {
	decomposed := norm.NFD.String(input)
	var b strings.Builder
	b.Grow(len(decomposed))

	for _, r := range decomposed {
		switch {
		case unicode.Is(unicode.Mn, r):
			continue
		case r == 'đ':
			b.WriteByte('d')
		default:
			b.WriteRune(r)
		}
	}

	folded, _, err := transform.String(norm.NFC, b.String())
	if err != nil {
		return b.String()
	}
	return folded
}

func replaceSymbolLeetInsideWords(input string) string {
	runes := []rune(input)
	var b strings.Builder
	b.Grow(len(input))

	for i, r := range runes {
		if replacement, ok := symbolLeetReplacement(r); ok && (hasWordRuneBefore(runes, i) || isTokenStart(runes, i)) && hasWordRuneAfter(runes, i) {
			b.WriteRune(replacement)
			continue
		}
		b.WriteRune(r)
	}

	return b.String()
}

func symbolLeetReplacement(r rune) (rune, bool) {
	switch r {
	case '!', '|':
		return 'i', true
	case '$':
		return 's', true
	case '@':
		return 'a', true
	default:
		return 0, false
	}
}

func hasWordRuneBefore(runes []rune, index int) bool {
	for i := index - 1; i >= 0; i-- {
		if unicode.IsSpace(runes[i]) {
			return false
		}
		if unicode.IsLetter(runes[i]) || unicode.IsDigit(runes[i]) {
			return true
		}
	}
	return false
}

func isTokenStart(runes []rune, index int) bool {
	return index == 0 || unicode.IsSpace(runes[index-1])
}

func hasWordRuneAfter(runes []rune, index int) bool {
	for i := index + 1; i < len(runes); i++ {
		if unicode.IsSpace(runes[i]) {
			return false
		}
		if unicode.IsLetter(runes[i]) || unicode.IsDigit(runes[i]) {
			return true
		}
	}
	return false
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

	tokens := strings.Fields(normalized)
	words := meaningfulWords(normalized)
	if looksLikeIsolatedLetterNoise(tokens, words) {
		return blockedContent(ContentSafetyCategoryGibberish, "isolated_letter_noise", "ticket content contains isolated random letters"), true
	}
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
	if containsUnnaturalLetterBigrams(words) {
		return blockedContent(ContentSafetyCategoryGibberish, "rare_letter_bigrams", "ticket content contains unlikely letter sequences"), true
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

func looksLikeIsolatedLetterNoise(tokens, words []string) bool {
	if len(tokens) == 0 || len(tokens) > 5 || len(words) > 2 {
		return false
	}

	noiseLetters := 0
	for _, token := range tokens {
		if len([]rune(token)) != 1 {
			continue
		}
		switch token {
		case "a", "i":
			continue
		default:
			noiseLetters++
		}
	}

	return noiseLetters >= 2
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

func containsUnnaturalLetterBigrams(words []string) bool {
	totalBigrams := 0
	rareBigrams := 0

	for _, word := range words {
		if !isAlphabeticASCIIWord(word) {
			continue
		}

		wordTotal, wordRare, wordRareRun := bigramStats(word)
		if len(word) >= minBigramGibberishWordLength && isUnnaturalBigramDistribution(wordTotal, wordRare, wordRareRun) {
			return true
		}

		totalBigrams += wordTotal
		rareBigrams += wordRare
	}

	return totalBigrams >= minBigramGibberishWordLength-1 &&
		float64(rareBigrams)/float64(totalBigrams) >= maxRareBigramRatio
}

func isAlphabeticASCIIWord(word string) bool {
	if word == "" {
		return false
	}
	for _, r := range word {
		if r < 'a' || r > 'z' {
			return false
		}
	}
	return true
}

func bigramStats(word string) (total, rare, maxRareRun int) {
	runes := []rune(word)
	if len(runes) < 2 {
		return 0, 0, 0
	}

	rareRun := 0
	for i := 0; i < len(runes)-1; i++ {
		total++
		bigram := string([]rune{runes[i], runes[i+1]})
		if commonEnglishBigrams[bigram] {
			rareRun = 0
			continue
		}
		rare++
		rareRun++
		if rareRun > maxRareRun {
			maxRareRun = rareRun
		}
	}

	return total, rare, maxRareRun
}

func isUnnaturalBigramDistribution(total, rare, maxRareRun int) bool {
	if total == 0 {
		return false
	}
	if maxRareRun >= maxConsecutiveRareBigrams {
		return true
	}
	return float64(rare)/float64(total) >= maxRareBigramRatio
}

func countMatches(text string, pattern *regexp.Regexp) int {
	return len(pattern.FindAllString(text, -1))
}

var commonEnglishBigrams = map[string]bool{
	"ab": true, "ac": true, "ad": true, "af": true, "ag": true, "ai": true, "ak": true, "al": true,
	"am": true, "an": true, "ap": true, "ar": true, "as": true, "at": true, "au": true, "av": true,
	"aw": true, "ay": true, "ba": true, "be": true, "bi": true, "bl": true, "bo": true, "br": true,
	"bu": true, "by": true, "ca": true, "ce": true, "ch": true, "ci": true, "ck": true, "cl": true,
	"co": true, "cr": true, "ct": true, "cu": true, "cy": true, "da": true, "de": true, "di": true,
	"do": true, "dr": true, "du": true, "ea": true, "ec": true, "ed": true, "ef": true, "eg": true,
	"ei": true, "el": true, "em": true, "en": true, "ep": true, "er": true, "es": true, "et": true,
	"ev": true, "ex": true, "fa": true, "fe": true, "fi": true, "fl": true, "fo": true, "fr": true,
	"ft": true, "fu": true, "ga": true, "ge": true, "gi": true, "gl": true, "go": true, "gr": true,
	"gu": true, "ha": true, "he": true, "hi": true, "ho": true, "ht": true, "hu": true, "ia": true,
	"ib": true, "ic": true, "id": true, "ie": true, "if": true, "ig": true, "il": true, "im": true,
	"in": true, "io": true, "ip": true, "ir": true, "is": true, "it": true, "iv": true, "ke": true,
	"ki": true, "kn": true, "la": true, "ld": true, "le": true, "li": true, "ll": true, "lo": true,
	"ls": true, "lt": true, "lu": true, "ly": true, "ma": true, "mb": true, "me": true, "mi": true,
	"mm": true, "mp": true, "ms": true, "mu": true, "my": true, "na": true, "nc": true, "nd": true,
	"ne": true, "ng": true, "ni": true, "nn": true, "no": true, "ns": true, "nt": true, "nu": true,
	"ny": true, "oa": true, "ob": true, "oc": true, "od": true, "of": true, "og": true, "oi": true,
	"ol": true, "om": true, "on": true, "oo": true, "op": true, "or": true, "os": true, "ot": true,
	"ou": true, "ov": true, "ow": true, "pa": true, "pe": true, "ph": true, "pi": true, "pl": true,
	"po": true, "pp": true, "pr": true, "pt": true, "pu": true, "qu": true, "ra": true, "rc": true,
	"rd": true, "re": true, "ri": true, "rk": true, "rl": true, "rm": true, "rn": true, "ro": true,
	"rs": true, "rt": true, "ru": true, "ry": true, "sa": true, "sc": true, "se": true, "sh": true,
	"si": true, "sk": true, "sl": true, "sm": true, "so": true, "sp": true, "ss": true, "st": true,
	"su": true, "ta": true, "tc": true, "te": true, "th": true, "ti": true, "tl": true, "to": true,
	"tr": true, "ts": true, "tu": true, "tw": true, "ty": true, "ua": true, "ub": true, "uc": true,
	"ud": true, "ue": true, "ug": true, "ui": true, "ul": true, "um": true, "un": true, "up": true,
	"ur": true, "us": true, "ut": true, "va": true, "ve": true, "vi": true, "vo": true, "wa": true,
	"we": true, "wh": true, "wi": true, "wo": true, "ye": true,
}
