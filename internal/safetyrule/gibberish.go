package safetyrule

import (
	"strings"
	"unicode"
)

const (
	minBigramGibberishWordLength = 12
	maxRareBigramRatio           = 0.45
	maxConsecutiveRareBigrams    = 4
	minVowelRatioWordLength      = 6
	minNaturalVowelRatio         = 0.10
	maxNaturalVowelRatio         = 0.80
	minSegmentBigramLength       = 4
	minLongAlphanumericLength    = 12
	maxLongAlphanumericRareRatio = 0.30
	minSymbolDigitNoiseLength    = 16
	minNumericNoiseDigits        = 16
	minShortRandomAlphaLength    = 8
	maxShortRandomAlphaLength    = 16
	maxShortRandomKnownRatio     = 0.75
)

type MatchResult struct {
	Category string
	Name     string
	Reason   string
}

func DetectGibberish(raw, normalized string) (MatchResult, bool) {
	return detectGibberish(raw, normalized)
}

func detectGibberish(raw, normalized string) (MatchResult, bool) {
	letters, digits, symbols := countSafetyTextClasses(raw)
	total := letters + digits + symbols
	if total > 0 && symbols >= 10 && float64(symbols)/float64(total) >= 0.70 {
		return gibberishMatch("symbol_heavy_content", "ticket content is mostly symbols"), true
	}
	if total >= minSymbolDigitNoiseLength && symbols >= 6 && digits >= 6 && letters == 0 {
		return gibberishMatch("symbol_digit_noise", "ticket content is mostly symbols and numbers"), true
	}

	tokens := strings.Fields(normalized)
	if looksLikeNumericNoise(tokens) {
		return gibberishMatch("numeric_noise", "ticket content is only a long numeric sequence"), true
	}

	words := meaningfulWords(normalized)
	if looksLikeIsolatedLetterNoise(tokens, words) {
		return gibberishMatch("isolated_letter_noise", "ticket content contains isolated random letters"), true
	}
	if len(words) == 0 {
		return MatchResult{}, false
	}

	if len(words) == 1 && hasRepeatedRun(words[0], 6, unicode.IsLetter) {
		return gibberishMatch("repeated_characters", "ticket content contains repeated characters"), true
	}
	if hasRepeatedRun(normalized, 12, unicode.IsLetter) || hasRepeatedRun(raw, 10, isPunctuation) {
		return gibberishMatch("repeated_characters", "ticket content contains repeated characters"), true
	}
	if len(words) >= 6 && mostRepeatedWordRatio(words) >= 0.80 {
		return gibberishMatch("repeated_words", "ticket content repeats the same words"), true
	}
	if looksLikeRepeatedNonsense(words) {
		return gibberishMatch("repeated_nonsense", "ticket content appears to be meaningless repetition"), true
	}
	if containsUnnaturalVowelRatio(words) {
		return gibberishMatch("unnatural_vowel_ratio", "ticket content contains unlikely vowel distribution"), true
	}
	if containsUnnaturalAlphanumericSegments(tokens) {
		return gibberishMatch("rare_letter_bigrams", "ticket content contains unlikely letter sequences"), true
	}
	if containsUnnaturalLetterBigrams(words) {
		return gibberishMatch("rare_letter_bigrams", "ticket content contains unlikely letter sequences"), true
	}
	if containsShortRandomAlphaToken(words) {
		return gibberishMatch("short_random_alpha_token", "ticket content contains random-looking text"), true
	}

	return MatchResult{}, false
}

func gibberishMatch(name, reason string) MatchResult {
	return MatchResult{
		Category: CategoryGibberish,
		Name:     name,
		Reason:   reason,
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

func looksLikeNumericNoise(tokens []string) bool {
	if len(tokens) == 0 || len(tokens) > 2 {
		return false
	}

	totalDigits := 0
	for _, token := range tokens {
		if token == "" {
			return false
		}
		for _, r := range token {
			if !unicode.IsDigit(r) {
				return false
			}
			totalDigits++
		}
	}
	return totalDigits >= minNumericNoiseDigits
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

func containsUnnaturalVowelRatio(words []string) bool {
	for _, word := range words {
		if !isAlphabeticASCIIWord(word) || len(word) < minVowelRatioWordLength {
			continue
		}
		ratio := vowelRatio(word)
		if ratio < minNaturalVowelRatio || ratio > maxNaturalVowelRatio {
			return true
		}
	}
	return false
}

func vowelRatio(word string) float64 {
	if word == "" {
		return 0
	}
	vowels := 0
	for _, r := range word {
		if strings.ContainsRune("aeiou", r) {
			vowels++
		}
	}
	return float64(vowels) / float64(len(word))
}

func containsUnnaturalAlphanumericSegments(tokens []string) bool {
	for _, token := range tokens {
		if !isAlphanumericASCII(token) || !containsASCIILetterAndDigit(token) {
			continue
		}
		for _, segment := range alphabeticSegments(token) {
			if len(segment) < minSegmentBigramLength {
				continue
			}
			total, rare, rareRun := bigramStats(segment)
			if isUnnaturalBigramDistribution(total, rare, rareRun) || isUnnaturalLongAlphanumericSegment(segment, total, rare) {
				return true
			}
		}
	}
	return false
}

func isUnnaturalLongAlphanumericSegment(segment string, total, rare int) bool {
	if len(segment) < minLongAlphanumericLength || total == 0 {
		return false
	}
	return float64(rare)/float64(total) >= maxLongAlphanumericRareRatio
}

func isAlphanumericASCII(token string) bool {
	if token == "" {
		return false
	}
	for _, r := range token {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			continue
		}
		return false
	}
	return true
}

func containsASCIILetterAndDigit(token string) bool {
	hasLetter := false
	hasDigit := false
	for _, r := range token {
		switch {
		case r >= 'a' && r <= 'z':
			hasLetter = true
		case r >= '0' && r <= '9':
			hasDigit = true
		}
	}
	return hasLetter && hasDigit
}

func alphabeticSegments(token string) []string {
	var segments []string
	var b strings.Builder

	flush := func() {
		if b.Len() == 0 {
			return
		}
		segments = append(segments, b.String())
		b.Reset()
	}

	for _, r := range token {
		if r >= 'a' && r <= 'z' {
			b.WriteRune(r)
			continue
		}
		if r >= '0' && r <= '9' {
			continue
		}
		flush()
	}
	flush()

	return segments
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

func containsShortRandomAlphaToken(words []string) bool {
	for _, word := range words {
		if !isAlphabeticASCIIWord(word) {
			continue
		}
		if len(word) < minShortRandomAlphaLength || len(word) > maxShortRandomAlphaLength {
			continue
		}
		if commonSupportWords[word] {
			continue
		}

		total, rare, rareRun := bigramStats(word)
		if total == 0 {
			continue
		}
		knownRatio := float64(total-rare) / float64(total)
		if knownRatio <= maxShortRandomKnownRatio || rareRun >= 2 {
			return true
		}
	}
	return false
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

var commonSupportWords = map[string]bool{
	"access": true, "account": true, "adapter": true, "administrator": true, "application": true,
	"anything": true, "approval": true, "asset": true, "attached": true, "authentication": true, "authorization": true,
	"backend": true, "balance": true, "boyfriend": true, "broken": true, "browser": true, "callback": true,
	"certificate": true, "characterization": true, "configuration": true, "connect": true, "connection": true, "controller": true,
	"credential": true, "database": true, "detected": true, "developer": true, "disconnect": true, "distribution": true,
	"electromagnetic": true, "employee": true, "equipment": true, "failed": true, "failure": true,
	"facilities": true, "gateway": true, "hardware": true, "incident": true, "internal": true,
	"internationalization": true, "investigation": true, "laptop": true, "login": true, "maintenance": true,
	"malfunction": true, "manager": true, "network": true, "occurred": true, "password": true, "payment": true,
	"permission": true, "printer": true, "production": true, "reconciliation": true, "replacement": true,
	"request": true, "response": true, "router": true, "service": true, "software": true,
	"submitted": true, "support": true, "system": true, "technical": true, "terrible": true, "ticket": true,
	"transaction": true, "troubleshooting": true, "update": true, "upgrade": true, "workplace": true,
}
