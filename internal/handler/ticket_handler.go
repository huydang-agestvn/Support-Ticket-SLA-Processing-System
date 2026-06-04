package handler

import (
	"log/slog"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/errmsgs"
	domain "support-ticket.com/internal/model"
	"support-ticket.com/internal/service"
)

type TicketHandler struct {
	ticketService service.TicketService
}

func NewTicketHandler(s service.TicketService) *TicketHandler {
	return &TicketHandler{
		ticketService: s,
	}
}

func parseTicketID(c *gin.Context) (uint, error) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		slog.WarnContext(c.Request.Context(), "invalid ticket id parameter",
			slog.String("id", idStr),
			slog.Any("error", err),
		)
		return 0, errmsgs.ErrInvalidInput
	}
	return uint(id), nil
}

func (h *TicketHandler) HandleCreateTicket(c *gin.Context) {
	var req request.CreateTicketReq
	if !BindJSONOrAbort(c, &req) {
		return
	}

	currentUser := auth.UserFromContext(c.Request.Context())
	req.RequestorID = currentUser.UserID

	ticket, err := h.ticketService.Create(c.Request.Context(), req)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusCreated, common.SuccessResponse(ticket))
}

func (h *TicketHandler) HandleListTickets(c *gin.Context) {
	var query struct {
		request.TicketFilter
		common.PaginationQuery
	}

	if !BindQueryOrAbort(c, &query) {
		return
	}

	tickets, err := h.ticketService.FindAll(c.Request.Context(), query.TicketFilter, query.PaginationQuery)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.APIResponse[*common.PaginatedResult[domain.Ticket]]{
		Success: true,
		Message: "Get tickets successfully",
		Data:    tickets,
	})
}

func (h *TicketHandler) HandleGetTicket(c *gin.Context) {
	id, err := parseTicketID(c)
	if err != nil {
		HandleError(c, err)
		return
	}

	ticket, err := h.ticketService.FindById(c.Request.Context(), id)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.SuccessResponse(ticket))
}

func (h *TicketHandler) HandleUpdateStatus(c *gin.Context) {
	id, err := parseTicketID(c)
	if err != nil {
		HandleError(c, err)
		return
	}

	var req request.UpdateStatusReq
	if !BindJSONOrAbort(c, &req) {
		return
	}

	err = h.ticketService.UpdateTicketStatus(c.Request.Context(), id, req)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.SuccessMessageResponse("Ticket status updated successfully"))
}
