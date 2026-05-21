package handler

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"support-ticket.com/internal/dto/common"
)

func HandleError(c *gin.Context, err error) {
	var apiErr *common.Error
	if errors.As(err, &apiErr) {
		c.JSON(apiErr.Status, common.ErrorResponse(apiErr))
		return
	}

	c.JSON(http.StatusInternalServerError, common.ErrorResponse(
		common.NewInternal("internal server error"),
	))
}

func BindJSONOrAbort(c *gin.Context, req interface{}) bool {
	if err := c.ShouldBindJSON(req); err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, common.ErrorResponse(
			common.NewBadRequest(common.ErrCodeInvalidBody, "invalid request body: "+err.Error()),
		))
		return false
	}
	return true
}

func BindQueryOrAbort(c *gin.Context, req interface{}) bool {
	if err := c.ShouldBindQuery(req); err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, common.ErrorResponse(
			common.NewBadRequest(common.ErrCodeInvalidQuery, "invalid query parameters: "+err.Error()),
		))
		return false
	}
	return true
}
