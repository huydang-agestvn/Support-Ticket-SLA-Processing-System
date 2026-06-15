package ai

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
)

type FallbackChainAdapter struct {
	adapters []TriageAdapter
}

func NewFallbackChainAdapter(adapters ...TriageAdapter) *FallbackChainAdapter {
	return &FallbackChainAdapter{
		adapters: adapters,
	}
}

func (a *FallbackChainAdapter) Model() string {
	if len(a.adapters) == 0 || a.adapters[0] == nil {
		return ""
	}
	return a.adapters[0].Model()
}

func (a *FallbackChainAdapter) AnalyzeTicket(ctx context.Context, data TriagePromptData) (*TriageResult, error) {
	return a.analyzeWithFallback(ctx, data, func(adapter TriageAdapter) (*TriageResult, error) {
		return adapter.AnalyzeTicket(ctx, data)
	})
}

func (a *FallbackChainAdapter) AnalyzeTicketWithVersion(ctx context.Context, data TriagePromptData, promptVersion string) (*TriageResult, error) {
	return a.analyzeWithFallback(ctx, data, func(adapter TriageAdapter) (*TriageResult, error) {
		return adapter.AnalyzeTicketWithVersion(ctx, data, promptVersion)
	})
}

func (a *FallbackChainAdapter) analyzeWithFallback(
	ctx context.Context,
	data TriagePromptData,
	analyze func(adapter TriageAdapter) (*TriageResult, error),
) (*TriageResult, error) {
	if len(a.adapters) == 0 {
		return nil, errors.New("no AI adapters are configured")
	}

	var lastResult *TriageResult
	var lastErr error

	for index, adapter := range a.adapters {
		if adapter == nil {
			lastErr = fmt.Errorf("AI adapter at index %d is not configured", index)
			logFallbackAttempt(ctx, "AI adapter is not configured, trying next fallback model", data, nil, lastErr, index)
			continue
		}

		result, err := analyze(adapter)
		if !ShouldTryNextAIAdapter(result, err) {
			return result, nil
		}

		lastResult = result
		lastErr = err

		if index < len(a.adapters)-1 {
			logFallbackAttempt(ctx, "AI adapter returned unusable result, trying next fallback model", data, result, err, index)
		}
	}

	logFallbackAttempt(ctx, "all AI adapters returned unusable results, safe fallback will be used", data, lastResult, lastErr, len(a.adapters)-1)

	if lastErr != nil {
		return lastResult, fmt.Errorf("all AI adapters failed, last error: %w", lastErr)
	}
	return lastResult, nil
}

func logFallbackAttempt(ctx context.Context, message string, data TriagePromptData, result *TriageResult, err error, adapterIndex int) {
	attrs := []slog.Attr{
		slog.Uint64("ticket_id", uint64(data.Ticket.ID)),
		slog.Int("adapter_index", adapterIndex),
	}
	if err != nil {
		attrs = append(attrs, slog.Any("error", err))
	}
	if result != nil {
		attrs = append(attrs, slog.Float64("confidence_score", result.ConfidenceScore))
	}
	slog.LogAttrs(ctx, slog.LevelWarn, message, attrs...)
}
