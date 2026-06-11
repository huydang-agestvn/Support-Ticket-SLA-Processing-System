package handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/service"
)

type EvaluationHandler struct {
	evaluationService service.EvaluationService
}

func NewEvaluationHandler(s service.EvaluationService) *EvaluationHandler {
	return &EvaluationHandler{
		evaluationService: s,
	}
}

func (h *EvaluationHandler) HandleRunTriageEvaluation(c *gin.Context) {
	var req request.AIEvaluationRequest
	if !BindJSONOrAbort(c, &req) {
		return
	}

	result, err := h.evaluationService.RunTriageEvaluation(c.Request.Context(), req)
	if err != nil {
		if strings.Contains(err.Error(), "not found") || strings.Contains(err.Error(), "no evaluation cases") {
			HandleError(c, common.NewBadRequest(common.ErrCodeInvalidInput, err.Error()))
			return
		}
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.SuccessResponse(result))
}
