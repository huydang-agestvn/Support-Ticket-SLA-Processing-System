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
	groupedRule("direct_common_profanity", CategoryProfanity, "ticket contains inappropriate language", MatchObfuscated, `fuck(?:s|ing|in)?`, `motherfucker(?:s)?`, `shit(?:s|ty)?`, `bullshit(?:s)?`, `asshole(?:s)?`, `bastard(?:s)?`, `bitch(?:es)?`, `cunt(?:s)?`, `twat(?:s)?`, `wank(?:er)?(?:s)?`),
	groupedRule("direct_common_insult", CategoryInsult, "ticket contains direct insulting language", MatchObfuscated, `idiot(?:s)?`, `st[ou]+pid(?:s)?`, `moron(?:s)?`, `dumb`, `jerk(?:s)?`, `loser(?:s)?`),
	groupedRule("contextual_trash_insult", CategoryInsult, "ticket contains direct insulting language", MatchObfuscated, `(?:you|u)\s+(?:are|r)\s+trash`, `(?:this|that|your|ur)\s+(?:team|service|support|ticket)\s+(?:is|r)\s+trash`),
	groupedRule("targeted_support_abuse", CategoryInsult, "ticket contains abusive language directed at support staff", MatchObfuscated, `(?:it\s+)?(?:support\s+)?(?:agent|staff|team|engineer|manager|helpdesk|service\s+desk)\s+(?:is|are|was|were)\s+(?:useless|worthless|incompetent|idiots?|morons?|terrible)`, `(?:support|helpdesk|service\s+desk)\s+(?:is|are|was|were)\s+(?:useless|worthless|incompetent|idiots?|morons?)`),
	groupedRule("partially_masked_common_profanity", CategoryProfanity, "ticket contains partially masked inappropriate language", MatchUnicode, `f[\s._\-]*\*+[\s._\-]*ck`, `sh[\s._\-]*\*+[\s._\-]*t`, `b[\s._\-]*\*+[\s._\-]*tch`, `c[\s._\-]*\*+[\s._\-]*nt`),
	groupedRule("abbreviated_common_profanity", CategoryProfanity, "ticket contains abbreviated inappropriate language", MatchUnicode, `f[\s._*\-]*k`, `f[\s._*\-]*c[\s._*\-]*k`, `f[\s._*\-]*u[\s._*\-]*k`),
	groupedRule("obfuscated_common_profanity", CategoryProfanity, "ticket contains obfuscated inappropriate language", MatchUnicode, obfuscatedWordPattern("fuck"), obfuscatedWordPattern("shit"), obfuscatedWordPattern("bitch"), obfuscatedWordPattern("cunt")),
	groupedRule("obfuscated_common_insult", CategoryInsult, "ticket contains obfuscated insulting language", MatchUnicode, obfuscatedWordPattern("idiot"), `st[\s._*\-]*[ou]+[\s._*\-]*p[\s._*\-]*i[\s._*\-]*d`, obfuscatedWordPattern("moron")),
	groupedRule("gambling_spam", CategorySpam, "ticket contains gambling promotional content", MatchNormalized, `casino promotion`, `place a bet`, `betting promotion`, `gambling promotion`),
	groupedRule("adult_content_spam", CategorySpam, "ticket contains adult promotional content", MatchNormalized, `porn links`, `free porn`, `adult links`, `xxx links`, `nsfw links`),
	groupedRule("direct_adult_content", CategorySpam, "ticket contains adult content", MatchNormalized, `porns?`, `pornos?`, `pornography`, `pornographic`, `xxx`, `nsfw`, `onlyfans`, `nudes?`),
	groupedRule("sexual_media_spam", CategorySpam, "ticket contains adult promotional content", MatchNormalized, `sex videos?`, `sex links?`, `sex clips?`, `sex images?`, `sex photos?`, `sex tapes?`, `watch sex`, `free sex`),
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
