package safetyrule

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"time"
)

type MLClassifier interface {
	Score(ctx context.Context, text string) (MLScore, error)
}

type MLScore struct {
	ToxicScore   float64
	ObsceneScore float64
}

type NoopMLClassifier struct{}

func (NoopMLClassifier) Score(ctx context.Context, text string) (MLScore, error) {
	return MLScore{}, nil
}

type HTTPMLClassifier struct {
	endpoint string
	timeout  time.Duration
	client   *http.Client
}

func NewHTTPMLClassifier(endpoint string, timeout time.Duration) *HTTPMLClassifier {
	return &HTTPMLClassifier{
		endpoint: endpoint,
		timeout:  timeout,
		client: &http.Client{
			Timeout: timeout,
		},
	}
}

func (c *HTTPMLClassifier) Score(ctx context.Context, text string) (MLScore, error) {
	if c == nil || c.endpoint == "" {
		return MLScore{}, nil
	}

	timeout := c.timeout
	if timeout <= 0 {
		timeout = 3 * time.Second
	}

	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	body, err := json.Marshal(struct {
		Text string `json:"text"`
	}{
		Text: text,
	})
	if err != nil {
		return MLScore{}, nil
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(body))
	if err != nil {
		return MLScore{}, nil
	}
	req.Header.Set("Content-Type", "application/json")

	client := c.client
	if client == nil {
		client = &http.Client{Timeout: timeout}
	}

	resp, err := client.Do(req)
	if err != nil {
		return MLScore{}, nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return MLScore{}, nil
	}

	var response struct {
		ToxicScore   float64 `json:"toxic_score"`
		ObsceneScore float64 `json:"obscene_score"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return MLScore{}, nil
	}

	return MLScore{
		ToxicScore:   response.ToxicScore,
		ObsceneScore: response.ObsceneScore,
	}, nil
}
