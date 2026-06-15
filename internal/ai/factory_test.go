package ai

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"support-ticket.com/internal/config"
)

func TestParseFallbackChainPreservesColonInModelID(t *testing.T) {
	targets := parseFallbackChain("groq:openai/gpt-oss-20b, openrouter:nex-agi/nex-n2-pro:free, gemini:gemini-3.5-flash")

	assert.Equal(t, []fallbackTarget{
		{provider: "groq", model: "openai/gpt-oss-20b"},
		{provider: "openrouter", model: "nex-agi/nex-n2-pro:free"},
		{provider: "gemini", model: "gemini-3.5-flash"},
	}, targets)
}

func TestFallbackTargetsUsesExplicitChain(t *testing.T) {
	cfg := &config.Config{
		AIProvider:      "groq",
		AIModel:         "primary",
		AIFallbackChain: "openrouter:nex-agi/nex-n2-pro:free",
	}

	targets := fallbackTargets(cfg)

	assert.Equal(t, []fallbackTarget{
		{provider: "openrouter", model: "nex-agi/nex-n2-pro:free"},
	}, targets)
}

func TestFallbackTargetsBuildsPrimaryOnlyWhenChainIsEmpty(t *testing.T) {
	cfg := &config.Config{
		AIProvider: "groq",
		AIModel:    "openai/gpt-oss-20b",
	}

	targets := fallbackTargets(cfg)

	assert.Equal(t, []fallbackTarget{
		{provider: "groq", model: "openai/gpt-oss-20b"},
	}, targets)
}

func TestProviderCredentialsFallsBackToActiveProviderKey(t *testing.T) {
	cfg := &config.Config{
		AIProvider: "groq",
		AIBaseURL:  "https://example.test/v1",
		AIAPIKey:   "active-provider-key",
	}

	baseURL, apiKey, ok := providerCredentials(cfg, "groq")

	assert.True(t, ok)
	assert.Equal(t, "https://example.test/v1", baseURL)
	assert.Equal(t, "active-provider-key", apiKey)
}

func TestProviderCredentialsRequiresProviderSpecificKeyForOtherProviders(t *testing.T) {
	cfg := &config.Config{
		AIProvider: "groq",
		AIAPIKey:   "groq-key",
	}

	_, _, ok := providerCredentials(cfg, "openrouter")

	assert.False(t, ok)
}
