package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
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

	if err := c.ShouldBindJSON(&input); err != nil {
		HandleError(c, common.NewBadRequest(
			common.ErrCodeInvalidBody,
			"invalid login request: "+err.Error(),
		))
		return
	}

	result, err := h.authService.Login(input)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.APIResponse[*response.LoginResponse]{
		Success: true,
		Message: "Login successfully",
		Data:    result,
	})
}
