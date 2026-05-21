package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
	_ "support-ticket.com/internal/dto/response/swagger_response"
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
// @Accept application/x-www-form-urlencoded
// @Produce json
// @Param username formData string true "Username"
// @Param password formData string true "Password" format(password)
// @Success 200 {object} swagger_response.LoginSuccessResponseDoc "Login successfully"
// @Failure 400 {object} swagger_response.BadRequestResponseDoc "Invalid request body"
// @Failure 401 {object} swagger_response.UnauthorizedResponseDoc "Invalid username or password"
// @Failure 500 {object} swagger_response.InternalServerErrorResponseDoc "Internal server error"
// @Failure 503 {object} swagger_response.ServiceUnavailableResponseDoc "Authentication provider unavailable"
// @Router /auth/login [post]
func (h *AuthHandler) Login(c *gin.Context) {
	var input request.LoginRequest

	if err := c.ShouldBind(&input); err != nil {
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
		Data:    result,
	})
}
