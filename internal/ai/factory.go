package ai

import (
	"context"
	"log/slog"
	"strings"

	"support-ticket.com/internal/config"
)

type fallbackTarget struct {
	provider string
	model    string
}

func NewAdapterFromConfig(cfg *config.Config) TriageAdapter {
	if cfg == nil || !cfg.AIEnabled {
		promptVersion := ""
		if cfg != nil {
			promptVersion = cfg.AIPromptVersion
		}
		return NewFakeAdapter(promptVersion)
	}

	adapters := fallbackAdapters(cfg)
	return NewFallbackChainAdapter(adapters...)
}

func fallbackAdapters(cfg *config.Config) []TriageAdapter {
	targets := fallbackTargets(cfg)
	adapters := make([]TriageAdapter, 0, len(targets))
	for _, target := range targets {
		baseURL, apiKey, ok := providerCredentials(cfg, target.provider)
		if !ok {
			slog.WarnContext(context.Background(), "skipping AI fallback provider because credentials are not configured",
				slog.String("provider", target.provider),
				slog.String("model", target.model),
			)
			continue
		}
		adapters = append(adapters, NewOpenAICompatibleAdapter(
			target.provider,
			baseURL,
			apiKey,
			target.model,
			cfg.AITimeoutSecs,
			cfg.AIMaxRetries,
			cfg.AIPromptVersion,
		))
	}
	return adapters
}

func fallbackTargets(cfg *config.Config) []fallbackTarget {
	if cfg == nil {
		return nil
	}

	if strings.TrimSpace(cfg.AIFallbackChain) != "" {
		return parseFallbackChain(cfg.AIFallbackChain)
	}

	provider := strings.ToLower(strings.TrimSpace(cfg.AIProvider))
	if provider == "" {
		provider = "groq"
	}

	targets := make([]fallbackTarget, 0, 3)
	seen := make(map[string]struct{})

	addModel := func(model string) {
		model = strings.TrimSpace(model)
		if model == "" {
			return
		}
		key := provider + ":" + model
		if _, exists := seen[key]; exists {
			return
		}
		seen[key] = struct{}{}
		targets = append(targets, fallbackTarget{
			provider: provider,
			model:    model,
		})
	}

	addModel(cfg.AIModel)

	return targets
}

func parseFallbackChain(rawChain string) []fallbackTarget {
	targets := make([]fallbackTarget, 0)
	seen := make(map[string]struct{})

	for _, rawTarget := range strings.Split(rawChain, ",") {
		rawTarget = strings.TrimSpace(rawTarget)
		if rawTarget == "" {
			continue
		}

		provider, model, ok := strings.Cut(rawTarget, ":")
		if !ok {
			slog.WarnContext(context.Background(), "skipping invalid AI fallback target; expected provider:model",
				slog.String("target", rawTarget),
			)
			continue
		}

		provider = strings.ToLower(strings.TrimSpace(provider))
		model = strings.TrimSpace(model)
		if provider == "" || model == "" {
			continue
		}

		key := provider + ":" + model
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		targets = append(targets, fallbackTarget{
			provider: provider,
			model:    model,
		})
	}

	return targets
}

func providerCredentials(cfg *config.Config, provider string) (string, string, bool) {
	provider = strings.ToLower(strings.TrimSpace(provider))
	switch provider {
	case "groq":
		baseURL := firstNonEmpty(cfg.AIGroqBaseURL, providerSpecificValue(cfg, provider, cfg.AIBaseURL), providerDefaultBaseURL(provider))
		apiKey := firstNonEmpty(cfg.AIGroqAPIKey, providerSpecificValue(cfg, provider, cfg.AIAPIKey))
		return baseURL, apiKey, baseURL != "" && apiKey != ""
	case "openrouter":
		baseURL := firstNonEmpty(cfg.AIOpenRouterBaseURL, providerSpecificValue(cfg, provider, cfg.AIBaseURL), providerDefaultBaseURL(provider))
		apiKey := firstNonEmpty(cfg.AIOpenRouterAPIKey, providerSpecificValue(cfg, provider, cfg.AIAPIKey))
		return baseURL, apiKey, baseURL != "" && apiKey != ""
	case "gemini", "google", "google-studio":
		baseURL := firstNonEmpty(cfg.AIGeminiBaseURL, providerSpecificValue(cfg, provider, cfg.AIBaseURL), providerDefaultBaseURL(provider))
		apiKey := firstNonEmpty(cfg.AIGeminiAPIKey, providerSpecificValue(cfg, provider, cfg.AIAPIKey))
		return baseURL, apiKey, baseURL != "" && apiKey != ""
	default:
		return "", "", false
	}
}

func providerSpecificValue(cfg *config.Config, provider string, value string) string {
	if strings.EqualFold(cfg.AIProvider, provider) {
		return value
	}
	return ""
}

func providerDefaultBaseURL(provider string) string {
	switch provider {
	case "groq":
		return "https://api.groq.com/openai/v1/chat/completions"
	case "openrouter":
		return "https://openrouter.ai/api/v1/chat/completions"
	case "gemini", "google", "google-studio":
		return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
	default:
		return ""
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			return value
		}
	}
	return ""
}
