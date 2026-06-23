package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// EmbeddingClient calls Ollama's native /api/embeddings endpoint to generate vectors.
type EmbeddingClient struct {
	baseURL     string
	model       string
	httpClient  *http.Client
}

// ollamaEmbedRequest matches Ollama's POST /api/embeddings schema
type ollamaEmbedRequest struct {
	Model  string `json:"model"`
	Prompt string `json:"prompt"`
}

// ollamaEmbedResponse matches Ollama's response schema
type ollamaEmbedResponse struct {
	Embedding []float32 `json:"embedding"`
}

// NewEmbeddingClient creates a client that calls Ollama for embeddings.
// baseURL: e.g. "http://localhost:11434"
// model:   e.g. "nomic-embed-text" (pulled via `ollama pull nomic-embed-text`)
func NewEmbeddingClient(baseURL, model string, timeoutSecs int) *EmbeddingClient {
	return &EmbeddingClient{
		baseURL: baseURL,
		model:   model,
		httpClient: &http.Client{
			Timeout: time.Duration(timeoutSecs) * time.Second,
		},
	}
}

// GetEmbedding sends text to Ollama and returns a float32 embedding vector.
func (c *EmbeddingClient) GetEmbedding(ctx context.Context, text string) ([]float32, error) {
	body, err := json.Marshal(ollamaEmbedRequest{Model: c.model, Prompt: text})
	if err != nil {
		return nil, fmt.Errorf("embedding client: failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/embeddings", bytes.NewBuffer(body))
	if err != nil {
		return nil, fmt.Errorf("embedding client: failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("embedding client: ollama request failed (is Ollama running?): %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("embedding client: ollama returned status %d", resp.StatusCode)
	}

	var result ollamaEmbedResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("embedding client: failed to decode ollama response: %w", err)
	}

	if len(result.Embedding) == 0 {
		return nil, fmt.Errorf("embedding client: ollama returned empty embedding (model '%s' loaded?)", c.model)
	}

	return result.Embedding, nil
}
