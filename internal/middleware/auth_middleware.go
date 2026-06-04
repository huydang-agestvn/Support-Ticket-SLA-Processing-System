package middleware

import (
	"log/slog"
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
			slog.WarnContext(c.Request.Context(), "missing authorization header")
			c.AbortWithStatusJSON(http.StatusUnauthorized, common.ErrorResponse(
				common.NewUnauthorized(common.ErrCodeUnauthorized, "authorization header is required"),
			))
			return
		}

		const bearerPrefix = "Bearer "
		if !strings.HasPrefix(authHeader, bearerPrefix) {
			slog.WarnContext(c.Request.Context(), "invalid authorization header format")
			c.AbortWithStatusJSON(http.StatusUnauthorized, common.ErrorResponse(
				common.NewUnauthorized(common.ErrCodeUnauthorized, "invalid authorization header format"),
			))
			return
		}

		tokenString := strings.TrimSpace(strings.TrimPrefix(authHeader, bearerPrefix))
		if tokenString == "" {
			slog.WarnContext(c.Request.Context(), "missing bearer token in authorization header")
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
			slog.WarnContext(c.Request.Context(), "unauthorized access attempt (no active user)")
			c.AbortWithStatusJSON(http.StatusUnauthorized, common.ErrorResponse(
				common.NewUnauthorized(common.ErrCodeUnauthorized, "unauthorized"),
			))
			return
		}

		if !currentUser.HasAnyRole(allowedRoles...) {
			slog.WarnContext(c.Request.Context(), "forbidden access attempt",
				slog.Any("required_roles", allowedRoles),
				slog.String("user_id", currentUser.UserID),
			)
			c.AbortWithStatusJSON(http.StatusForbidden, common.ErrorResponse(
				common.NewForbidden(common.ErrCodeForbidden, "forbidden: insufficient role"),
			))
			return
		}

		c.Next()
	}
}
