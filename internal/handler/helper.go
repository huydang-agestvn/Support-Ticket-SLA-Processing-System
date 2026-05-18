package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"support-ticket.com/internal/dto/common"
)

func BindJSONOrAbort(c *gin.Context, req interface{}) bool {
	if err := c.ShouldBindJSON(req); err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, common.APIResponse[interface{}]{
			Success: false,
			Error:   "invalid request body: " + err.Error(),
		})
		return false
	}
	return true
}


func BindQueryOrAbort(c *gin.Context, req interface{}) bool {
	if err := c.ShouldBindQuery(req); err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, common.APIResponse[interface{}]{
			Success: false,
			Error:   "invalid query parameters: " + err.Error(),
		})
		return false
	}
	return true
}
