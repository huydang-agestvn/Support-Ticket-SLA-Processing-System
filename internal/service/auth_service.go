package service

import (
	"fmt"
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

	if username == "" || password == "" {
		return nil, fmt.Errorf("username and password are required")
	}

	tokenResp, err := s.keycloakClient.Login(username, password)
	if err != nil {
		return nil, err
	}

	tokenType := tokenResp.TokenType
	if tokenType == "" {
		tokenType = "Bearer"
	}

	return &response.LoginResponse{
		AccessToken:  tokenResp.AccessToken,
		RefreshToken: tokenResp.RefreshToken,
		TokenType:    tokenType,
		ExpiresIn:    tokenResp.ExpiresIn,
	}, nil
}
