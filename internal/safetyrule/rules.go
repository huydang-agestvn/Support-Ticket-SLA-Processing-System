package safetyrule

import (
	"regexp"
	"strings"
)

const (
	CategoryProfanity = "profanity"
	CategoryInsult    = "insult"
	CategorySpam      = "spam"
	CategoryGibberish = "gibberish"

	MaxAllowedURLs   = 5
	MaxAllowedEmails = 5
)

type MatchInput string

const (
	MatchNormalized MatchInput = "normalized"
	MatchObfuscated MatchInput = "obfuscated"
	MatchUnicode    MatchInput = "unicode"
)

type Rule struct {
	Name       string
	Pattern    *regexp.Regexp
	Category   string
	Reason     string
	MatchInput MatchInput
}

var Rules = []Rule{
	groupedRule("direct_common_profanity", CategoryProfanity, "ticket contains inappropriate language", MatchObfuscated, `fuck(?:ing|in)?`, `motherfucker`, `shit(?:ty)?`, `bullshit`, `asshole`, `bastard`, `bitch(?:es)?`, `cunt`, `twat`, `wank(?:er)?`),
	groupedRule("direct_common_insult", CategoryInsult, "ticket contains direct insulting language", MatchObfuscated, `idiot`, `st[ou]+pid`, `moron`, `dumb`, `jerk`, `loser`),
	groupedRule("contextual_trash_insult", CategoryInsult, "ticket contains direct insulting language", MatchObfuscated, `(?:you|u)\s+(?:are|r)\s+trash`, `(?:this|that|your|ur)\s+(?:team|service|support|ticket)\s+(?:is|r)\s+trash`),
	groupedRule("partially_masked_common_profanity", CategoryProfanity, "ticket contains partially masked inappropriate language", MatchUnicode, `f[\s._\-]*\*+[\s._\-]*ck`, `sh[\s._\-]*\*+[\s._\-]*t`, `b[\s._\-]*\*+[\s._\-]*tch`, `c[\s._\-]*\*+[\s._\-]*nt`),
	groupedRule("obfuscated_common_profanity", CategoryProfanity, "ticket contains obfuscated inappropriate language", MatchUnicode, obfuscatedWordPattern("fuck"), obfuscatedWordPattern("shit"), obfuscatedWordPattern("bitch"), obfuscatedWordPattern("cunt")),
	groupedRule("obfuscated_common_insult", CategoryInsult, "ticket contains obfuscated insulting language", MatchUnicode, obfuscatedWordPattern("idiot"), `st[\s._*\-]*[ou]+[\s._*\-]*p[\s._*\-]*i[\s._*\-]*d`, obfuscatedWordPattern("moron")),
	groupedRule("gambling_spam", CategorySpam, "ticket contains gambling promotional content", MatchNormalized, `casino promotion`, `place a bet`, `betting promotion`, `gambling promotion`),
	groupedRule("adult_content_spam", CategorySpam, "ticket contains adult promotional content", MatchNormalized, `porn links`, `free porn`, `adult links`, `xxx links`, `nsfw links`),
	groupedRule("illegal_drug_spam", CategorySpam, "ticket contains illegal drug promotional content", MatchNormalized, `buy illegal drugs`, `illegal drugs from`, `buy cocaine`, `buy heroin`),
}

var (
	URLPattern   = regexp.MustCompile(`(?i)https?://|www\.`)
	EmailPattern = regexp.MustCompile(`(?i)[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}`)
	PromoPattern = regexp.MustCompile(`\b(buy now|limited offer|free money)\b`)
)

func groupedRule(name, category, reason string, input MatchInput, alternatives ...string) Rule {
	return Rule{
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
