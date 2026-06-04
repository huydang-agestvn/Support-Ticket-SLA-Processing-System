package service

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
)

type AuthService interface {
	Login(input request.LoginRequest) (*response.LoginResponse, error)
}

type authServiceImpl struct {
	keycloakClient *ClientRequest
}

func NewAuthService(keycloakClient *ClientRequest) AuthService {
	return &authServiceImpl{
		keycloakClient: keycloakClient,
	}
}

func (s *authServiceImpl) Login(input request.LoginRequest) (*response.LoginResponse, error) {
	username := strings.TrimSpace(input.Username)
	password := strings.TrimSpace(input.Password)

	if username == "" {
		return nil, fmt.Errorf("username is required")
	}

	if password == "" {
		return nil, fmt.Errorf("password is required")
	}

	tokenResp, err := s.keycloakClient.Login(username, password)
	if err != nil {
		slog.ErrorContext(context.Background(), "login failed",
			slog.String("username", username),
			slog.Any("error", err),
		)
		return nil, err
	}

	slog.InfoContext(context.Background(), "login successful",
		slog.String("username", username),
	)

	return &response.LoginResponse{
		AccessToken: tokenResp.AccessToken,
		TokenType:   tokenResp.TokenType,
		ExpiresIn:   tokenResp.ExpiresIn,
	}, nil
}
