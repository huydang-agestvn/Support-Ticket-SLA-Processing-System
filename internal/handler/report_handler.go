package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"support-ticket.com/internal/dto/common"
	_ "support-ticket.com/internal/dto/response/swagger_response"
	"support-ticket.com/internal/service"
)

type ReportHandler struct {
	reportSvc service.ReportService
}

func NewReportHandler(reportSvc service.ReportService) *ReportHandler {
	return &ReportHandler{reportSvc: reportSvc}
}

// GetDaily godoc
// @Summary Get daily report
// @Description Get daily ticket report by date
// @Tags Reports
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param date query string false "Report date in YYYY-MM-DD format"
// @Success 200 {object} common.SuccessResponseDoc "Get daily report successfully"
// @Failure 400 {object} common.ErrorResponseDoc "Invalid date format"
// @Failure 401 {object} common.ErrorResponseDoc "Unauthorized"
// @Failure 404 {object} common.ErrorResponseDoc "Report not found"
// @Failure 500 {object} common.ErrorResponseDoc "Internal server error"
// @Router /reports/daily [get]
func (h *ReportHandler) GetDaily(c *gin.Context) {
	dateStr := c.DefaultQuery("date", time.Now().Format("2006-01-02"))

	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, common.ErrorResponse(
			common.NewBadRequest(common.ErrCodeInvalidInput, "invalid date format, expected YYYY-MM-DD"),
		))
		return
	}

	report, err := h.reportSvc.GetReport(date)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.SuccessResponse(report))
}
