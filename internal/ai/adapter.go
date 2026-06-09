package ai

import (
    "context"
    "support-ticket.com/internal/dto/request"
    "support-ticket.com/internal/dto/response"
)

type AIAdapter interface {
    Triage(ctx context.Context, req request.TriageRequest) (*response.TriageResponse, error)
}