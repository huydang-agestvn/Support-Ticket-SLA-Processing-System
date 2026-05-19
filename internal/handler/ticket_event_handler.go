package handler

import (
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
	dto "support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/service"
)

type TicketEventHandler struct {
	service service.TicketEventService
}

func NewTicketEventHandler(service service.TicketEventService) *TicketEventHandler {
	return &TicketEventHandler{
		service: service,
	}
}

// ImportEvents godoc
// @Summary Import ticket events
// @Description Import ticket events in batch using worker pool
// @Tags ticket-events
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body map[string]interface{} true "Import ticket events request"
// @Success 200 {object} common.APIResponse[response.TicketImportResponse]
// @Failure 400 {object} common.APIResponse[any]
// @Failure 500 {object} common.APIResponse[any]
// @Router /ticket-events/import [post]
func (h *TicketEventHandler) ImportEvents(c *gin.Context) {
	ctx := c.Request.Context()

	data, err := io.ReadAll(c.Request.Body)
	if err != nil {
		HandleError(c, err)
		return
	}
	defer c.Request.Body.Close()

	result, err := h.service.Import(ctx, data)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, dto.APIResponse[interface{}]{
		Success: true,
		Data:    response.NewTicketImportResponse(result),
		Message: "import completed",
	})
}
