package openrouter

import (
	"context"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/ai/provider"
	openaiadapter "support-ticket.com/internal/ai/provider/openai"
)

type Adapter struct {
	client *openaiadapter.Adapter
}

func NewAdapter(cfg provider.Config) *Adapter {
	cfg.ProviderName = "openrouter"
	return &Adapter{client: openaiadapter.NewAdapter(cfg)}
}

func (a *Adapter) Model() string {
	return a.client.Model()
}

func (a *Adapter) AnalyzeTicket(ctx context.Context, data ai.TriagePromptData) (*ai.TriageResult, error) {
	return a.client.AnalyzeTicket(ctx, data)
}

func (a *Adapter) AnalyzeTicketWithVersion(ctx context.Context, data ai.TriagePromptData, promptVersion string) (*ai.TriageResult, error) {
	return a.client.AnalyzeTicketWithVersion(ctx, data, promptVersion)
}
