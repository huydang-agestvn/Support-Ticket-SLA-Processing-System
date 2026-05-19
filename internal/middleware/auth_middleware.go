package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/handler"
)

type AuthMiddleware struct {
	authenticator *auth.KeycloakAuthenticator
}

func NewAuthMiddleware(authenticator *auth.KeycloakAuthenticator) *AuthMiddleware {
	return &AuthMiddleware{
		authenticator: authenticator,
	}
}

func (m *AuthMiddleware) RequireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")

		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, common.ErrorResponse(
				common.NewUnauthorized(common.ErrCodeUnauthorized, "authorization header is required"),
			))
			return
		}

		const bearerPrefix = "Bearer "
		if !strings.HasPrefix(authHeader, bearerPrefix) {
			c.AbortWithStatusJSON(http.StatusUnauthorized, common.ErrorResponse(
				common.NewUnauthorized(common.ErrCodeUnauthorized, "invalid authorization header format"),
			))
			return
		}

		tokenString := strings.TrimSpace(strings.TrimPrefix(authHeader, bearerPrefix))
		if tokenString == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, common.ErrorResponse(
				common.NewUnauthorized(common.ErrCodeUnauthorized, "missing bearer token"),
			))
			return
		}

		currentUser, err := m.authenticator.VerifyToken(tokenString)
		if err != nil {
			handler.HandleError(c, err)
			c.Abort()
			return
		}

		ctx := auth.WithUser(c.Request.Context(), currentUser)
		c.Request = c.Request.WithContext(ctx)

		c.Next()
	}
}

func (m *AuthMiddleware) RequireRole(allowedRoles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		currentUser := auth.UserFromContext(c.Request.Context())

		if currentUser.UserID == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, common.ErrorResponse(
				common.NewUnauthorized(common.ErrCodeUnauthorized, "unauthorized"),
			))
			return
		}

		if !currentUser.HasAnyRole(allowedRoles...) {
			c.AbortWithStatusJSON(http.StatusForbidden, common.ErrorResponse(
				common.NewForbidden(common.ErrCodeForbidden, "forbidden: insufficient role"),
			))
			return
		}

		c.Next()
	}
}
