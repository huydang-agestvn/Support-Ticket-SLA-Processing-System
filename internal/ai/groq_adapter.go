package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// GroqAdapter implements the TriageAdapter using the Groq API.
type GroqAdapter struct {
	apiKey        string
	model         string
	httpClient    *http.Client
	baseURL       string
	maxRetries    int
	promptVersion string
}

// NewGroqAdapter initializes a new adapter for Groq.
func NewGroqAdapter(baseURL, apiKey, model string, timeoutSecs int, maxRetries int, promptVersion string) *GroqAdapter {
	return &GroqAdapter{
		apiKey: apiKey,
		model:  model,
		httpClient: &http.Client{
			Timeout: time.Duration(timeoutSecs) * time.Second,
		},
		baseURL:       baseURL,
		maxRetries:    maxRetries,
		promptVersion: promptVersion,
	}
}

// groqRequest represents the payload for the Groq API
type groqRequest struct {
	Model          string         `json:"model"`
	Messages       []groqMessage  `json:"messages"`
	Temperature    float64        `json:"temperature"`
	ResponseFormat responseFormat `json:"response_format"`
}

type groqMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type responseFormat struct {
	Type       string      `json:"type"`
	JSONSchema *jsonSchema `json:"json_schema,omitempty"`
}

type jsonSchema struct {
	Name   string         `json:"name"`
	Strict bool           `json:"strict"`
	Schema map[string]any `json:"schema"`
}

type groqResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

// AnalyzeTicket sends the ticket details to Groq and enforces strict JSON schema output.
func (g *GroqAdapter) AnalyzeTicket(ctx context.Context, data TriagePromptData) (*TriageResult, error) {
	var historyBuilder bytes.Buffer
	for _, event := range data.Events {
		historyBuilder.WriteString(fmt.Sprintf("- [%s] Status changed from %s to %s by Assignee %s\n", 
			event.CreatedAt.Format(time.RFC3339), event.FromStatus, event.ToStatus, event.AssigneeID))
	}
	if len(data.Events) == 0 {
		historyBuilder.WriteString("No previous events.\n")
	}

	prompt := fmt.Sprintf(`Analyze the following support ticket and provide triage information.
Ticket ID: %d
Title: %s
Description: %s
Priority: %s
Requestor ID: %s
Created At: %s

Event History:
%s

SLA Policy & Daily Stats:
%s
%s`, data.Ticket.ID, data.Ticket.Title, data.Ticket.Description, data.Ticket.Priority, data.Ticket.RequestorID, data.Ticket.CreatedAt.Format(time.RFC3339), historyBuilder.String(), data.SLAPolicy, data.DailyStats)

	// Define the strict JSON schema required by Task 2
	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"category": map[string]any{
				"type":        "string",
				"description": "The category of the ticket",
			},
			"urgency_level": map[string]any{
				"type":        "string",
				"description": "Urgency level: low, medium, high",
			},
			"sla_breach_risk": map[string]any{
				"type":        "string",
				"description": "Risk of SLA breach: low, medium, high",
			},
			"reason_summary": map[string]any{
				"type":        "string",
				"description": "A brief explanation of the reasoning",
			},
			"recommended_next_action": map[string]any{
				"type":        "string",
				"description": "Recommended action for the operator",
			},
			"confidence_score": map[string]any{
				"type":        "number",
				"description": "Confidence score between 0.0 and 1.0 based on the available context",
			},
			"fallback_used": map[string]any{
				"type":        "boolean",
				"description": "Must always be false for AI generated responses",
			},
		},
		"required": []string{
			"category", "urgency_level", "sla_breach_risk",
			"reason_summary", "recommended_next_action",
			"confidence_score", "fallback_used",
		},
		"additionalProperties": false,
	}

	reqBody := groqRequest{
		Model:       g.model,
		Temperature: 0.0, // Use 0.0 for deterministic output required in Triage
		Messages: []groqMessage{
			{
				Role:    "system",
				Content: "You are an AI Service Desk Triage Assistant. You must extract and infer details strictly following the JSON schema format.",
			},
			{
				Role:    "user",
				Content: prompt,
			},
		},
		ResponseFormat: responseFormat{
			Type: "json_schema", // Enforce strict JSON output
			JSONSchema: &jsonSchema{
				Name:   "triage_result",
				Strict: true,
				Schema: schema,
			},
		},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal groq request: %w", err)
	}

	var lastErr error
	for attempt := 0; attempt <= g.maxRetries; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Duration(attempt) * time.Second) // Exponential-ish backoff
		}

		req, err := http.NewRequestWithContext(ctx, "POST", g.baseURL, bytes.NewBuffer(jsonData))
		if err != nil {
			return nil, fmt.Errorf("failed to create request: %w", err)
		}

		req.Header.Set("Authorization", "Bearer "+g.apiKey)
		req.Header.Set("Content-Type", "application/json")

		// Call the LLM Provider
		resp, err := g.httpClient.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("groq api request failed: %w", err)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			var errResp map[string]any
			_ = json.NewDecoder(resp.Body).Decode(&errResp)
			resp.Body.Close()
			lastErr = fmt.Errorf("groq api returned error: status %d, details: %v", resp.StatusCode, errResp)
			continue
		}

		var groqResp groqResponse
		if err := json.NewDecoder(resp.Body).Decode(&groqResp); err != nil {
			resp.Body.Close()
			lastErr = fmt.Errorf("failed to decode groq response: %w", err)
			continue
		}
		resp.Body.Close()

		if len(groqResp.Choices) == 0 {
			lastErr = fmt.Errorf("groq returned no choices")
			continue
		}

		content := groqResp.Choices[0].Message.Content

		// Parse structured JSON response mapped exactly to our output
		var result TriageResult
		if err := json.Unmarshal([]byte(content), &result); err != nil {
			lastErr = fmt.Errorf("failed to parse structured json response: %w", err)
			continue
		}

		// Double-check the fallback flag
		result.FallbackUsed = false
		result.PromptVersion = g.promptVersion

		return &result, nil
	}

	return nil, fmt.Errorf("max retries exceeded, last error: %w", lastErr)
}
