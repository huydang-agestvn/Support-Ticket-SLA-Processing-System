package ai_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	aifactory "support-ticket.com/internal/ai/factory"
	"support-ticket.com/internal/config"
)

func TestFactoryReturnsFakeAdapterWhenAIDisabled(t *testing.T) {
	adapter := aifactory.NewAdapterFromConfig(&config.Config{
		AIEnabled:       false,
		AIPromptVersion: "v1.1",
	})

	assert.Equal(t, "fake-model", adapter.Model())
}

func TestFactoryBuildsPrimaryOnlyWhenFallbackChainIsEmpty(t *testing.T) {
	adapter := aifactory.NewAdapterFromConfig(&config.Config{
		AIEnabled:  true,
		AIProvider: "groq",
		AIModel:    "openai/gpt-oss-20b",
		AIAPIKey:   "test-key",
	})

	assert.Equal(t, "openai/gpt-oss-20b", adapter.Model())
}

func TestFactoryFallbackChainPreservesColonInModelID(t *testing.T) {
	adapter := aifactory.NewAdapterFromConfig(&config.Config{
		AIEnabled:       true,
		AIFallbackChain: "ollama:qwen2.5:0.5b,groq:openai/gpt-oss-20b",
		AIGroqAPIKey:    "groq-key",
	})

	assert.Equal(t, "qwen2.5:0.5b", adapter.Model())
}

func TestFactoryUsesPrimaryBeforeFallbackChain(t *testing.T) {
	adapter := aifactory.NewAdapterFromConfig(&config.Config{
		AIEnabled:       true,
		AIProvider:      "groq",
		AIModel:         "openai/gpt-oss-20bsad",
		AIFallbackChain: "groq:openai/gpt-oss-120b,ollama:qwen2.5:0.5b",
		AIGroqAPIKey:    "groq-key",
	})

	assert.Equal(t, "openai/gpt-oss-20bsad", adapter.Model())
}

func TestFactorySupportsOllamaAsPrimary(t *testing.T) {
	adapter := aifactory.NewAdapterFromConfig(&config.Config{
		AIEnabled:  true,
		AIProvider: "ollama",
		AIModel:    "qwen2.5:0.5b",
		AIBaseURL:  "http://localhost:11434/api/chat",
	})

	assert.Equal(t, "qwen2.5:0.5b", adapter.Model())
}

func TestFactorySupportsOllamaInFallbackChain(t *testing.T) {
	adapter := aifactory.NewAdapterFromConfig(&config.Config{
		AIEnabled:       true,
		AIFallbackChain: "ollama:qwen2.5:0.5b,groq:openai/gpt-oss-20b",
		AIGroqAPIKey:    "groq-key",
	})

	assert.Equal(t, "qwen2.5:0.5b", adapter.Model())
}

func TestFactorySkipsFallbackProvidersWithoutCredentials(t *testing.T) {
	adapter := aifactory.NewAdapterFromConfig(&config.Config{
		AIEnabled:       true,
		AIFallbackChain: "unsupported:test-model,groq:openai/gpt-oss-20b",
		AIGroqAPIKey:    "groq-key",
	})

	assert.Equal(t, "openai/gpt-oss-20b", adapter.Model())
}
