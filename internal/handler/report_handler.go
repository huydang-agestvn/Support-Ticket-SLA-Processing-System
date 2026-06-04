package handler

import (
	"log/slog"
	"net/http"
	"strings"
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
		slog.WarnContext(c.Request.Context(), "invalid date format",
			slog.String("date", dateStr),
			slog.Any("error", err),
		)
		c.JSON(http.StatusBadRequest, common.ErrorResponse(
			common.NewBadRequest(common.ErrCodeInvalidInput, "invalid date format, expected YYYY-MM-DD"),
		))
		return
	}

	report, err := h.reportSvc.GetReport(date)
	if err != nil {
		if strings.Contains(err.Error(), "report not found") {
			slog.WarnContext(c.Request.Context(), "report not found",
				slog.Time("date", date),
			)
			c.JSON(http.StatusNotFound, common.ErrorResponse(
				common.NewNotFound(common.ErrCodeNotFound, "report not yet available for this date, please contact your administrator to generate it"),
			))
			return
		}
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.SuccessResponse(report))
}
