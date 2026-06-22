package service_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"support-ticket.com/internal/service"
)

func TestContentSafetyService_CheckTicket(t *testing.T) {
	svc := service.NewContentSafetyService()

	tests := []struct {
		name             string
		title            string
		description      string
		expectedBlocked  bool
		expectedCategory string
	}{
		{
			name:            "SafeTicket",
			title:           "Cannot connect to VPN",
			description:     "I cannot connect to the company VPN from home.",
			expectedBlocked: false,
		},
		{
			name:             "Insult",
			title:            "You are stupid",
			description:      "Fix this internal support request now.",
			expectedBlocked:  true,
			expectedCategory: service.ContentSafetyCategoryInsult,
		},
		{
			name:             "CommonProfanity",
			title:            "This is bullshit",
			description:      "Fix this internal support request now.",
			expectedBlocked:  true,
			expectedCategory: service.ContentSafetyCategoryProfanity,
		},
		{
			name:             "ObfuscatedInsult",
			title:            "You are stoopid",
			description:      "Fix this internal support request now.",
			expectedBlocked:  true,
			expectedCategory: service.ContentSafetyCategoryInsult,
		},
		{
			name:             "ContextualTrashInsult",
			title:            "You are trash",
			description:      "Fix this internal support request now.",
			expectedBlocked:  true,
			expectedCategory: service.ContentSafetyCategoryInsult,
		},
		{
			name:             "ContextualTrashServiceInsult",
			title:            "This service is trash",
			description:      "Fix this internal support request now.",
			expectedBlocked:  true,
			expectedCategory: service.ContentSafetyCategoryInsult,
		},
		{
			name:            "SensitiveIncidentReportAllowed",
			title:           "Harassment report",
			description:     "I want to report sexual harassment at work.",
			expectedBlocked: false,
		},
		{
			name:             "ClearlyNonWorkSensitiveSpam",
			title:            "Casino promotion",
			description:      "Visit this casino promotion now and place a bet.",
			expectedBlocked:  true,
			expectedCategory: service.ContentSafetyCategorySpam,
		},
		{
			name:             "Gibberish",
			title:            "aaaaaaaaaaaaa",
			description:      "!!!!!!!!!!!!!!",
			expectedBlocked:  true,
			expectedCategory: service.ContentSafetyCategoryGibberish,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := svc.CheckTicket(tt.title, tt.description)

			assert.Equal(t, tt.expectedBlocked, result.Blocked)
			if tt.expectedBlocked {
				assert.Equal(t, tt.expectedCategory, result.Category)
				assert.NotEmpty(t, result.Reason)
				assert.NotEmpty(t, result.MatchedRule)
			} else {
				assert.Empty(t, result.Category)
			}
		})
	}
}

func TestContentSafetyService_ObfuscationAndUnicode(t *testing.T) {
	svc := service.NewContentSafetyService()

	tests := []struct {
		name     string
		input    string
		category string
	}{
		{name: "PunctuatedIdiot", input: "i.d.i.o.t", category: service.ContentSafetyCategoryInsult},
		{name: "SpacedIdiot", input: "i d i o t", category: service.ContentSafetyCategoryInsult},
		{name: "HyphenatedIdiot", input: "i-d-i-o-t", category: service.ContentSafetyCategoryInsult},
		{name: "StarStupid", input: "st*upid", category: service.ContentSafetyCategoryInsult},
		{name: "DotStupid", input: "st.upid", category: service.ContentSafetyCategoryInsult},
		{name: "LeetStupid", input: "stup1d", category: service.ContentSafetyCategoryInsult},
		{name: "LeetMoron", input: "m0ron", category: service.ContentSafetyCategoryInsult},
		{name: "FullWidthIdiot", input: "ｉｄｉｏｔ", category: service.ContentSafetyCategoryInsult},
		{name: "ZeroWidthIdiot", input: "id\u200Biot", category: service.ContentSafetyCategoryInsult},
		{name: "ZeroWidthStupid", input: "stu\u200Dpid", category: service.ContentSafetyCategoryInsult},
		{name: "ObfuscatedProfanity", input: "f.u.c.k", category: service.ContentSafetyCategoryProfanity},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := svc.CheckTicket(tt.input, "Please handle this request.")

			assert.True(t, result.Blocked)
			assert.Equal(t, tt.category, result.Category)
		})
	}
}

func TestContentSafetyService_AllowsValidShortTechnicalTickets(t *testing.T) {
	svc := service.NewContentSafetyService()

	tests := []string{
		"VPN down",
		"PC broken",
		"WiFi slow",
		"MFA failed",
		"SSO locked",
		"API returned 500",
		"Cannot access 10.0.0.1",
		"HTTP 401 after login",
		"Need VPN",
		"Mouse dead",
		"OS issue",
		"LAN down",
		"bug",
		"lag",
		"dns",
		"git",
	}

	for _, text := range tests {
		t.Run(text, func(t *testing.T) {
			result := svc.CheckTicket(text, "")

			assert.False(t, result.Blocked)
		})
	}
}

func TestContentSafetyService_AllowsLegitimateSensitiveWorkplaceReports(t *testing.T) {
	svc := service.NewContentSafetyService()

	tests := []string{
		"I want to report sexual harassment at work.",
		"An employee threatened me during a meeting.",
		"I need to report suspected drug use in the office.",
		"My boyfriend keeps contacting me through the company email system.",
	}

	for _, text := range tests {
		t.Run(text, func(t *testing.T) {
			result := svc.CheckTicket("Incident report", text)

			assert.False(t, result.Blocked)
			assert.Empty(t, result.Category)
		})
	}
}

func TestContentSafetyService_BlocksClearlyNonWorkSensitiveContent(t *testing.T) {
	svc := service.NewContentSafetyService()

	tests := []string{
		"Visit this casino promotion now and place a bet.",
		"Free porn links available here.",
		"Buy illegal drugs from this website.",
	}

	for _, text := range tests {
		t.Run(text, func(t *testing.T) {
			result := svc.CheckTicket("Spam", text)

			assert.True(t, result.Blocked)
			assert.Equal(t, service.ContentSafetyCategorySpam, result.Category)
		})
	}
}

func TestContentSafetyService_BlocksSpamAndGibberish(t *testing.T) {
	svc := service.NewContentSafetyService()

	tests := []struct {
		name     string
		title    string
		text     string
		category string
	}{
		{name: "Symbols", text: "@@@@@@@@@@@@@@@", category: service.ContentSafetyCategoryGibberish},
		{name: "NumbersOnly", text: "123456789012345", category: service.ContentSafetyCategoryGibberish},
		{name: "RepeatedNonsense", text: "asdfasdfasdfasdf", category: service.ContentSafetyCategoryGibberish},
		{name: "RepeatedWords", text: "hello hello hello hello hello", category: service.ContentSafetyCategoryGibberish},
		{name: "RepeatedAcronym", text: "VPN VPN VPN VPN VPN", category: service.ContentSafetyCategoryGibberish},
		{name: "ExcessiveUrls", title: "Request", text: "See http://a.test http://b.test http://c.test http://d.test http://e.test http://f.test", category: service.ContentSafetyCategorySpam},
		{name: "ExcessiveEmails", title: "Request", text: "Send to a@example.com b@example.com c@example.com d@example.com e@example.com f@example.com", category: service.ContentSafetyCategorySpam},
		{name: "PromotionalPhrase", title: "Request", text: "Limited offer click here for free money", category: service.ContentSafetyCategorySpam},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := svc.CheckTicket(tt.title, tt.text)

			assert.True(t, result.Blocked)
			assert.Equal(t, tt.category, result.Category)
		})
	}
}

func TestContentSafetyService_DeterministicFirstMatch(t *testing.T) {
	svc := service.NewContentSafetyService()

	var first service.ContentSafetyResult
	for i := 0; i < 10; i++ {
		result := svc.CheckTicket("You are an idiot", "Visit this casino promotion now and place a bet.")

		assert.True(t, result.Blocked)

		if i == 0 {
			first = result
			continue
		}
		assert.Equal(t, first.Category, result.Category)
		assert.Equal(t, first.Reason, result.Reason)
		assert.Equal(t, first.MatchedRule, result.MatchedRule)
	}
}

func TestContentSafetyService_AllowsLegitimateClickHere(t *testing.T) {
	svc := service.NewContentSafetyService()

	result := svc.CheckTicket(
		"Portal link broken",
		"The instructions say click here to open the HR portal, but the link returns HTTP 404.",
	)

	assert.False(t, result.Blocked)
	assert.Empty(t, result.Category)
}

func TestContentSafetyService_AllowsFacilitiesTrashTickets(t *testing.T) {
	svc := service.NewContentSafetyService()

	tests := []struct {
		title       string
		description string
	}{
		{
			title:       "Trash bin broken",
			description: "The trash bin on floor 18 is broken.",
		},
		{
			title:       "Trash bin full",
			description: "Your trash bin is full.",
		},
		{
			title:       "Trash container broken",
			description: "This trash container is broken.",
		},
		{
			title:       "Pantry cleaning request",
			description: "Please collect the trash near the pantry.",
		},
		{
			title:       "Trash pickup missed",
			description: "The trash service did not arrive today.",
		},
	}

	for _, tt := range tests {
		t.Run(tt.title, func(t *testing.T) {
			result := svc.CheckTicket(tt.title, tt.description)

			assert.False(t, result.Blocked)
			assert.Empty(t, result.Category)
		})
	}
}
