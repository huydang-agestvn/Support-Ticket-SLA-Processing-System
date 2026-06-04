package handler

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"
	"support-ticket.com/internal/dto/common"
)

func HandleError(c *gin.Context, err error) {
	var apiErr *common.Error
	if errors.As(err, &apiErr) {
		if apiErr.Status >= 500 {
			slog.ErrorContext(c.Request.Context(), "api error",
				slog.Int("status", apiErr.Status),
				slog.String("code", apiErr.Code),
				slog.String("message", apiErr.Message),
			)
		} else {
			slog.WarnContext(c.Request.Context(), "api error",
				slog.Int("status", apiErr.Status),
				slog.String("code", apiErr.Code),
				slog.String("message", apiErr.Message),
			)
		}
		c.JSON(apiErr.Status, common.ErrorResponse(apiErr))
		return
	}

	slog.ErrorContext(c.Request.Context(), "internal server error",
		slog.Any("error", err),
	)
	c.JSON(http.StatusInternalServerError, common.ErrorResponse(
		common.NewInternal("internal server error"),
	))
}

func BindJSONOrAbort(c *gin.Context, req interface{}) bool {
	if err := c.ShouldBindJSON(req); err != nil {
		slog.WarnContext(c.Request.Context(), "invalid request body",
			slog.Any("error", err),
		)
		c.AbortWithStatusJSON(http.StatusBadRequest, common.ErrorResponse(
			common.NewBadRequest(common.ErrCodeInvalidBody, "invalid request body: "+err.Error()),
		))
		return false
	}
	return true
}

func BindQueryOrAbort(c *gin.Context, req interface{}) bool {
	if err := c.ShouldBindQuery(req); err != nil {
		slog.WarnContext(c.Request.Context(), "invalid query parameters",
			slog.Any("error", err),
		)
		c.AbortWithStatusJSON(http.StatusBadRequest, common.ErrorResponse(
			common.NewBadRequest(common.ErrCodeInvalidQuery, "invalid query parameters: "+err.Error()),
		))
		return false
	}
	return true
}
