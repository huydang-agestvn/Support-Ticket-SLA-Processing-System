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
	authService *service.AuthService
}

func NewAuthHandler(authService *service.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
	}
}

// Login godoc
// @Summary Login
// @Description Login with username and password through Keycloak
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body request.LoginRequest true "Login request"
// @Success 200 {object} common.SuccessResponseDoc "Login successfully"
// @Failure 400 {object} common.ErrorResponseDoc "Invalid request body"
// @Failure 401 {object} common.ErrorResponseDoc "Invalid username or password"
// @Router /auth/login [post]
func (h *AuthHandler) Login(c *gin.Context) {
	var input request.LoginRequest

	if !BindJSONOrAbort(c, &input) {
		return
	}

	result, err := h.authService.Login(input)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.APIResponse[*response.LoginResponse]{
		Success: true,
		Data:    result,
	})
}
