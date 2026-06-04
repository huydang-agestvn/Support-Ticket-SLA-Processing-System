package handler

import (
	"io"
	"log/slog"
	"net/http"
	"path/filepath"
	"strings"

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

func readImportInput(c *gin.Context) (data []byte, format string, err error) {
	if strings.Contains(c.GetHeader("Content-Type"), "multipart/form-data") {
		file, header, ferr := c.Request.FormFile("file")
		if ferr != nil {
			slog.WarnContext(c.Request.Context(), "missing or invalid file field in multipart form",
				slog.Any("error", ferr),
			)
			return nil, "", dto.NewBadRequest(dto.ErrCodeInvalidBody, "missing or invalid 'file' field in multipart form")
		}
		defer file.Close()

		format = strings.ToLower(strings.TrimPrefix(filepath.Ext(header.Filename), "."))
		data, err = io.ReadAll(file)
		return
	}

	// Raw JSON body (backward compatible)
	defer c.Request.Body.Close()
	data, err = io.ReadAll(c.Request.Body)
	format = "json"
	return
}

func (h *TicketEventHandler) ImportEvents(c *gin.Context) {
	ctx := c.Request.Context()

	data, format, err := readImportInput(c)
	if err != nil {
		HandleError(c, err)
		return
	}

	events, err := parseEvents(data, format)
	if err != nil {
		HandleError(c, err)
		return
	}
	result, err := h.service.Import(ctx, events)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, dto.APIResponse[interface{}]{
		Success: true,
		Message: "import ticket events successfully",
		Data:    response.NewTicketImportResponse(result),
	})
}

func (h *TicketEventHandler) DownloadAuditLog(c *gin.Context) {
	filename := c.Param("filename")
	if filename == "" {
		slog.WarnContext(c.Request.Context(), "missing filename parameter for audit log download")
		HandleError(c, dto.NewBadRequest(dto.ErrCodeInvalidInput, "filename parameter is required"))
		return
	}

	filePath, err := h.service.GetAuditLogPath(filename)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.Header("Content-Description", "File Transfer")
	c.Header("Content-Disposition", "attachment; filename="+filepath.Base(filePath))
	c.Header("Content-Type", "text/csv")
	c.Header("Content-Transfer-Encoding", "binary")
	c.File(filePath)
}
