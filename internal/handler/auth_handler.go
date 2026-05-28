package handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/service"
)

type AuthHandler struct {
	authService service.AuthService
}

func NewAuthHandler(authService service.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
	}
}

func (h *AuthHandler) Login(c *gin.Context) {
	var input request.LoginRequest

	contentType := c.GetHeader("Content-Type")

	if strings.Contains(contentType, "application/x-www-form-urlencoded") {
		input.Username = c.PostForm("username")
		input.Password = c.PostForm("password")
	} else {
		if err := c.ShouldBindJSON(&input); err != nil {
			HandleError(c, common.NewBadRequest(
				common.ErrCodeInvalidBody,
				"invalid login request: "+err.Error(),
			))
			return
		}
	}

	result, err := h.authService.Login(input)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token":  result.AccessToken,
		"refresh_token": result.RefreshToken,
		"token_type":    result.TokenType,
		"expires_in":    result.ExpiresIn,
	})
}
