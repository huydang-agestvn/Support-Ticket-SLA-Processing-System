package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"support-ticket.com/internal/dto/common"
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