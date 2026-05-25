package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/service"
)

type ReportHandler struct {
	reportSvc service.ReportService
}

func NewReportHandler(reportSvc service.ReportService) *ReportHandler {
	return &ReportHandler{reportSvc: reportSvc}
}

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
