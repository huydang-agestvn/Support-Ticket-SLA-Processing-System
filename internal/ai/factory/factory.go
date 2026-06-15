package factory

import (
	"context"
	"log/slog"
	"strings"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/ai/provider"
	"support-ticket.com/internal/ai/provider/gemini"
	"support-ticket.com/internal/ai/provider/groq"
	"support-ticket.com/internal/ai/provider/openrouter"
	"support-ticket.com/internal/config"
)

type fallbackTarget struct {
	provider string
	model    string
}

func NewAdapterFromConfig(cfg *config.Config) ai.TriageAdapter {
	if cfg == nil || !cfg.AIEnabled {
		promptVersion := ""
		if cfg != nil {
			promptVersion = cfg.AIPromptVersion
		}
		return ai.NewFakeAdapter(promptVersion)
	}

	adapters := fallbackAdapters(cfg)
	return ai.NewFallbackChainAdapter(adapters...)
}

func fallbackAdapters(cfg *config.Config) []ai.TriageAdapter {
	targets := fallbackTargets(cfg)
	adapters := make([]ai.TriageAdapter, 0, len(targets))
	for _, target := range targets {
		providerCfg, ok := providerConfig(cfg, target)
		if !ok {
			slog.WarnContext(context.Background(), "skipping AI fallback provider because credentials are not configured",
				slog.String("provider", target.provider),
				slog.String("model", target.model),
			)
			continue
		}
		adapter, ok := newProviderAdapter(providerCfg)
		if !ok {
			slog.WarnContext(context.Background(), "skipping unsupported AI fallback provider",
				slog.String("provider", target.provider),
				slog.String("model", target.model),
			)
			continue
		}
		adapters = append(adapters, adapter)
	}
	return adapters
}

func newProviderAdapter(providerCfg provider.Config) (ai.TriageAdapter, bool) {
	switch normalizeProvider(providerCfg.ProviderName) {
	case "groq":
		return groq.NewAdapter(providerCfg), true
	case "openrouter":
		return openrouter.NewAdapter(providerCfg), true
	case "gemini":
		return gemini.NewAdapter(providerCfg), true
	default:
		return nil, false
	}
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

	targets := make([]fallbackTarget, 0, 1)
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

		provider = normalizeProvider(provider)
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

func providerConfig(cfg *config.Config, target fallbackTarget) (provider.Config, bool) {
	providerName := normalizeProvider(target.provider)
	baseURL, apiKey, ok := providerCredentials(cfg, providerName)
	if !ok {
		return provider.Config{}, false
	}

	return provider.Config{
		ProviderName:  providerName,
		BaseURL:       baseURL,
		APIKey:        apiKey,
		Model:         strings.TrimSpace(target.model),
		TimeoutSecs:   cfg.AITimeoutSecs,
		MaxRetries:    cfg.AIMaxRetries,
		PromptVersion: cfg.AIPromptVersion,
	}, true
}

func providerCredentials(cfg *config.Config, provider string) (string, string, bool) {
	provider = normalizeProvider(provider)
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

func normalizeProvider(provider string) string {
	provider = strings.ToLower(strings.TrimSpace(provider))
	switch provider {
	case "google", "google-studio":
		return "gemini"
	default:
		return provider
	}
}

func providerSpecificValue(cfg *config.Config, provider string, value string) string {
	if normalizeProvider(cfg.AIProvider) == normalizeProvider(provider) {
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
