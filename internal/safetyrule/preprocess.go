package safetyrule

import (
	"strings"
	"unicode"

	"golang.org/x/text/transform"
	"golang.org/x/text/unicode/norm"
)

type SafetyTextRepresentations struct {
	Raw              string
	Unicode          string
	Normalized       string
	FoldedNormalized string
	Obfuscated       string
}

func (r SafetyTextRepresentations) IsEmpty() bool {
	return strings.TrimSpace(r.Raw) == ""
}

func BuildSafetyTextRepresentations(title, description string) SafetyTextRepresentations {
	return buildSafetyTextRepresentations(title, description)
}

func buildSafetyTextRepresentations(title, description string) SafetyTextRepresentations {
	raw := strings.TrimSpace(title + " " + description)
	unicodeText := strings.ToLower(removeZeroWidthCharacters(norm.NFKC.String(raw)))
	normalized := normalizeSafetyText(unicodeText)
	foldedText := foldLatinText(unicodeText)
	foldedNormalized := normalizeSafetyText(foldedText)
	symbolLeetNormalized := normalizeSafetyText(replaceSymbolLeetInsideWords(unicodeText))

	return SafetyTextRepresentations{
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
