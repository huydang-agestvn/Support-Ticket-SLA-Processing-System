package service

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/url"
	"strings"

	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/response"
)

type ClientRequest struct {
	tokenURL     string
	clientID     string
	clientSecret string
	httpClient   *http.Client
}

func NewClient(tokenURL, clientID, clientSecret string) *ClientRequest {
	slog.InfoContext(context.Background(), "initializing new keycloak client",
		slog.String("token_url", tokenURL),
		slog.String("client_id", clientID),
	)

	return &ClientRequest{
		tokenURL:     tokenURL,
		clientID:     clientID,
		clientSecret: clientSecret,
		httpClient:   &http.Client{},
	}
}

func (c *ClientRequest) Login(username, password string) (*response.KeycloakTokenResponse, error) {
	if c.tokenURL == "" || c.clientID == "" || c.clientSecret == "" {
		return nil, common.NewInternal("authentication service is misconfigured")
	}

	form := url.Values{}
	form.Set("grant_type", "password")
	form.Set("client_id", c.clientID)
	form.Set("client_secret", c.clientSecret)
	form.Set("username", username)
	form.Set("password", password)

	req, err := http.NewRequest(
		http.MethodPost,
		c.tokenURL,
		strings.NewReader(form.Encode()),
	)
	if err != nil {
		return nil, common.NewInternal("authentication service is misconfigured")
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		slog.ErrorContext(context.Background(), "keycloak unreachable",
			slog.Any("error", err),
		)
		return nil, newServiceUnavailable("authentication service is temporarily unavailable")
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		var kcErr response.KeycloakErrorResponse
		_ = json.NewDecoder(resp.Body).Decode(&kcErr)

		if resp.StatusCode >= 400 && resp.StatusCode < 500 {
			return nil, common.NewUnauthorized(common.ErrCodeUnauthorized, "invalid username or password")
		}
		slog.ErrorContext(context.Background(), "keycloak returned error",
			slog.Int("status_code", resp.StatusCode),
			slog.String("kc_error", kcErr.Error),
			slog.String("kc_error_description", kcErr.ErrorDescription),
		)
		return nil, newServiceUnavailable("authentication service is temporarily unavailable")
	}

	var tokenResp response.KeycloakTokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return nil, common.NewInternal("failed to process authentication response")
	}

	if tokenResp.AccessToken == "" {
		return nil, common.NewInternal("authentication service returned an empty token")
	}

	return &tokenResp, nil
}

func newServiceUnavailable(message string) *common.Error {
	return &common.Error{
		Code:    "SERVICE_UNAVAILABLE",
		Status:  http.StatusServiceUnavailable,
		Message: message,
	}
}

var _ error = (*common.Error)(nil)
