package openai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"text/template"
	"time"

	"support-ticket.com/internal/ai"
	"support-ticket.com/internal/ai/provider"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
)

type Adapter struct {
	providerName  string
	apiKey        string
	model         string
	httpClient    *http.Client
	baseURL       string
	maxRetries    int
	promptVersion string
	headers       map[string]string
}

func NewAdapter(cfg provider.Config) *Adapter {
	timeoutSecs := cfg.TimeoutSecs
	if timeoutSecs <= 0 {
		timeoutSecs = 30
	}

	return &Adapter{
		providerName:  strings.TrimSpace(cfg.ProviderName),
		apiKey:        cfg.APIKey,
		model:         cfg.Model,
		httpClient:    &http.Client{Timeout: time.Duration(timeoutSecs) * time.Second},
		baseURL:       normalizeChatCompletionsURL(cfg.BaseURL),
		maxRetries:    cfg.MaxRetries,
		promptVersion: cfg.PromptVersion,
		headers:       cfg.Headers,
	}
}

func (a *Adapter) Model() string {
	return a.model
}

func (a *Adapter) AnalyzeTicket(ctx context.Context, data ai.TriagePromptData) (*ai.TriageResult, error) {
	return a.AnalyzeTicketWithVersion(ctx, data, a.promptVersion)
}

func (a *Adapter) AnalyzeTicketWithVersion(ctx context.Context, data ai.TriagePromptData, promptVersion string) (*ai.TriageResult, error) {
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

	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"category": map[string]any{
				"type":        "string",
				"enum":        []string{"IT", "HR", "Facilities"},
				"description": "The category of the ticket",
			},
			"urgency_level": map[string]any{
				"type":        "string",
				"enum":        []string{"low", "medium", "high"},
				"description": "Urgency level",
			},
			"sla_breach_risk": map[string]any{
				"type":        "string",
				"enum":        []string{"low", "medium", "high"},
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
				"minimum":     0.0,
				"maximum":     1.0,
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

	reqBody := request.GroqRequest{
		Model:       a.model,
		Temperature: 0.0,
		Messages: []request.GroqMessage{
			{
				Role:    "system",
				Content: "You are an AI Service Desk Triage Assistant. You must extract and infer details strictly following the JSON schema format.",
			},
			{
				Role:    "user",
				Content: prompt,
			},
		},
		ResponseFormat: request.ResponseFormat{
			Type: "json_schema",
			JSONSchema: &request.JSONSchema{
				Name:   "triage_result",
				Strict: true,
				Schema: schema,
			},
		},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal ai provider request: %w", err)
	}

	var lastErr error
	for attempt := 0; attempt <= a.maxRetries; attempt++ {
		if attempt > 0 {
			if err := sleepBeforeRetry(ctx, attempt); err != nil {
				return nil, err
			}
		}

		req, err := http.NewRequestWithContext(ctx, "POST", a.baseURL, bytes.NewBuffer(jsonData))
		if err != nil {
			return nil, fmt.Errorf("failed to create request: %w", err)
		}

		req.Header.Set("Authorization", "Bearer "+a.apiKey)
		req.Header.Set("Content-Type", "application/json")
		for key, value := range a.headers {
			if strings.TrimSpace(key) != "" && strings.TrimSpace(value) != "" {
				req.Header.Set(key, value)
			}
		}

		resp, err := a.httpClient.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("%s api request failed: %w", a.providerName, err)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			var errResp map[string]any
			_ = json.NewDecoder(resp.Body).Decode(&errResp)
			resp.Body.Close()
			lastErr = fmt.Errorf("%s api returned error: status %d, details: %v", a.providerName, resp.StatusCode, errResp)
			continue
		}

		var providerResp response.GroqResponse
		if err := json.NewDecoder(resp.Body).Decode(&providerResp); err != nil {
			resp.Body.Close()
			lastErr = fmt.Errorf("failed to decode %s response: %w", a.providerName, err)
			continue
		}
		resp.Body.Close()

		if len(providerResp.Choices) == 0 {
			lastErr = fmt.Errorf("%s returned no choices", a.providerName)
			continue
		}

		content := providerResp.Choices[0].Message.Content

		var result ai.TriageResult
		if err := json.Unmarshal([]byte(content), &result); err != nil {
			lastErr = fmt.Errorf("failed to parse structured json response: %w", err)
			continue
		}

		result.FallbackUsed = false
		result.PromptVersion = promptVersion

		return &result, nil
	}

	return nil, fmt.Errorf("max retries exceeded, last error: %w", lastErr)
}

func (a *Adapter) DetermineNextAction(ctx context.Context, data ai.NextActionPromptData) (string, error) {
	templatePath := "internal/ai/prompts/next_action_v1.0.tmpl"
	tmpl, err := template.ParseFiles(templatePath)
	if err != nil {
		return "", fmt.Errorf("failed to load prompt template %s: %w", templatePath, err)
	}

	var promptBuffer bytes.Buffer
	if err := tmpl.Execute(&promptBuffer, data); err != nil {
		return "", fmt.Errorf("failed to render prompt template: %w", err)
	}
	prompt := promptBuffer.String()

	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"recommended_next_action": map[string]any{
				"type":        "string",
				"description": "Recommended action for the operator",
			},
		},
		"required": []string{"recommended_next_action"},
		"additionalProperties": false,
	}

	reqBody := request.GroqRequest{
		Model: a.model,
		Messages: []request.GroqMessage{
			{
				Role:    "user",
				Content: prompt,
			},
		},
		Temperature: 0.2, // Low temp for more deterministic output
		ResponseFormat: request.ResponseFormat{
			Type: "json_schema",
			JSONSchema: &request.JSONSchema{
				Name:   "next_action_schema",
				Schema: schema,
				Strict: true,
			},
		},
	}

	reqBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	var lastErr error
	for attempt := 1; attempt <= a.maxRetries; attempt++ {
		req, err := http.NewRequestWithContext(ctx, "POST", normalizeChatCompletionsURL(a.baseURL), bytes.NewBuffer(reqBytes))
		if err != nil {
			return "", fmt.Errorf("failed to create http request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+a.apiKey)

		resp, err := a.httpClient.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("http request failed: %w", err)
			_ = sleepBeforeRetry(ctx, attempt)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			lastErr = fmt.Errorf("unexpected status code: %d", resp.StatusCode)
			_ = sleepBeforeRetry(ctx, attempt)
			continue
		}

		var providerResp response.GroqResponse
		if err := json.NewDecoder(resp.Body).Decode(&providerResp); err != nil {
			resp.Body.Close()
			lastErr = fmt.Errorf("failed to decode response: %w", err)
			_ = sleepBeforeRetry(ctx, attempt)
			continue
		}
		resp.Body.Close()

		if len(providerResp.Choices) == 0 {
			lastErr = fmt.Errorf("empty choices in response")
			_ = sleepBeforeRetry(ctx, attempt)
			continue
		}

		content := providerResp.Choices[0].Message.Content
		if content == "" {
			lastErr = fmt.Errorf("returned empty content")
			_ = sleepBeforeRetry(ctx, attempt)
			continue
		}

		var result map[string]string
		if err := json.Unmarshal([]byte(content), &result); err != nil {
			lastErr = fmt.Errorf("failed to parse structured json response: %w", err)
			_ = sleepBeforeRetry(ctx, attempt)
			continue
		}

		return result["recommended_next_action"], nil
	}

	return "", fmt.Errorf("max retries exceeded, last error: %w", lastErr)
}

func normalizeChatCompletionsURL(baseURL string) string {
	baseURL = strings.TrimSpace(baseURL)
	if baseURL == "" || strings.HasSuffix(baseURL, "/chat/completions") {
		return baseURL
	}
	return strings.TrimRight(baseURL, "/") + "/chat/completions"
}

func sleepBeforeRetry(ctx context.Context, attempt int) error {
	backoff := time.Duration(attempt) * time.Second
	timer := time.NewTimer(backoff)
	defer timer.Stop()

	select {
	case <-timer.C:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}
