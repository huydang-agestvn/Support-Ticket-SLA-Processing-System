package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"text/template"
	"time"

	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
)

// OllamaAdapter implements the TriageAdapter using the Ollama API.
type OllamaAdapter struct {
	model         string
	httpClient    *http.Client
	baseURL       string
	maxRetries    int
	promptVersion string
}

// NewOllamaAdapter initializes a new adapter for Ollama.
func NewOllamaAdapter(baseURL, model string, timeoutSecs int, maxRetries int, promptVersion string) *OllamaAdapter {
	return &OllamaAdapter{
		model: model,
		httpClient: &http.Client{
			Timeout: time.Duration(timeoutSecs) * time.Second,
		},
		baseURL:       baseURL,
		maxRetries:    maxRetries,
		promptVersion: promptVersion,
	}
}

// Model returns the configured LLM model name.
func (o *OllamaAdapter) Model() string {
	return o.model
}

// AnalyzeTicket sends the ticket details to Ollama and enforces strict JSON schema output.
func (o *OllamaAdapter) AnalyzeTicket(ctx context.Context, data TriagePromptData) (*TriageResult, error) {
	return o.AnalyzeTicketWithVersion(ctx, data, o.promptVersion)
}

// AnalyzeTicketWithVersion sends the ticket details to Ollama using a specific prompt version.
func (o *OllamaAdapter) AnalyzeTicketWithVersion(ctx context.Context, data TriagePromptData, promptVersion string) (*TriageResult, error) {
	templatePath := fmt.Sprintf("internal/ai/prompts/triage_%s.tmpl", promptVersion)
	tmpl, err := template.ParseFiles(templatePath)
	if err != nil {
		return nil, fmt.Errorf("failed to load prompt template %s: %w", templatePath, err)
	}

	var promptBuffer bytes.Buffer
	if err := tmpl.Execute(&promptBuffer, data); err != nil {
		return nil, fmt.Errorf("failed to render prompt template: %w", err)
	}
	prompt := promptBuffer.String()

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
				"description": "Urgency level",
			},
			"sla_breach_risk": map[string]any{
				"type":        "string",
				"description": "Risk of SLA breach",
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

	reqBody := request.OllamaRequest{
		Model: o.model,
		Messages: []request.OllamaMessage{
			{
				Role:    "system",
				Content: "You are an AI Service Desk Triage Assistant. You must extract and infer details strictly following the JSON schema format.",
			},
			{
				Role:    "user",
				Content: prompt,
			},
		},
		Format: schema, // Enforce strict JSON output
		Options: request.OllamaOptions{
			Temperature: 0.0,
		},
		Stream: false,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal ollama request: %w", err)
	}

	var lastErr error
	for attempt := 0; attempt <= o.maxRetries; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Duration(attempt) * time.Second) // Exponential-ish backoff
		}

		req, err := http.NewRequestWithContext(ctx, "POST", o.baseURL, bytes.NewBuffer(jsonData))
		if err != nil {
			return nil, fmt.Errorf("failed to create request: %w", err)
		}

		req.Header.Set("Content-Type", "application/json")

		// Call the LLM Provider
		resp, err := o.httpClient.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("ollama api request failed: %w", err)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			var errResp map[string]any
			_ = json.NewDecoder(resp.Body).Decode(&errResp)
			resp.Body.Close()
			lastErr = fmt.Errorf("ollama api returned error: status %d, details: %v", resp.StatusCode, errResp)
			continue
		}

		var ollamaResp response.OllamaResponse
		if err := json.NewDecoder(resp.Body).Decode(&ollamaResp); err != nil {
			resp.Body.Close()
			lastErr = fmt.Errorf("failed to decode ollama response: %w", err)
			continue
		}
		fmt.Println(ollamaResp.Message.Content)
		resp.Body.Close()

		content := ollamaResp.Message.Content
		if content == "" {
			lastErr = fmt.Errorf("ollama returned empty content")
			continue
		}

		// Parse structured JSON response mapped exactly to our output
		var result TriageResult
		if err := json.Unmarshal([]byte(content), &result); err != nil {
			lastErr = fmt.Errorf("failed to parse structured json response: %w", err)
			continue
		}

		// Double-check the fallback flag
		result.FallbackUsed = false
		result.PromptVersion = promptVersion

		return &result, nil
	}

	return nil, fmt.Errorf("max retries exceeded, last error: %w", lastErr)
}
