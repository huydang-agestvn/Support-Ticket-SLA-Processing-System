package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/service"
)

type TriageHandler struct {
	triageService service.TriageService
}

func NewTriageHandler(s service.TriageService) *TriageHandler {
	return &TriageHandler{
		triageService: s,
	}
}

func (h *TriageHandler) HandleTriageTicket(c *gin.Context) {
	id, err := parseTicketID(c)
	if err != nil {
		HandleError(c, err)
		return
	}

	result, err := h.triageService.ExecuteTriage(c.Request.Context(), id)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.SuccessResponse(result))
}

func (h *TriageHandler) HandleGetLatestTriage(c *gin.Context) {
	id, err := parseTicketID(c)
	if err != nil {
		HandleError(c, err)
		return
	}

	result, err := h.triageService.GetLatestTriageResult(c.Request.Context(), id)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.SuccessResponse(result))
}

func (h *TriageHandler) HandleBatchTriageTickets(c *gin.Context) {
	var req request.AIBatchTriageRequest
	if !BindJSONOrAbort(c, &req) {
		return
	}

	results, err := h.triageService.ExecuteBatchTriage(c.Request.Context(), req.TicketIDs)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.APIResponse[any]{
		Success: true,
		Message: "Batch triage job dispatched successfully to the worker pool",
		Data:    results,
	})
}

