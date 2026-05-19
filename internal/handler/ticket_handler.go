package handler

import (
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
		return 0, errmsgs.ErrInvalidInput
	}
	return uint(id), nil
}

// HandleCreateTicket godoc
// @Summary Create ticket
// @Description Create a new support ticket
// @Tags Tickets
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body request.CreateTicketReq true "Create ticket request"
// @Success 201 {object} common.APIResponse[domain.Ticket] "Ticket created successfully"
// @Failure 400 {object} common.APIResponse[any] "Invalid request body or invalid priority"
// @Failure 500 {object} common.APIResponse[any] "Internal server error"
// @Router /tickets [post]
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

// HandleListTickets godoc
// @Summary List tickets
// @Description Get tickets with filters and pagination
// @Tags Tickets
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param status query string false "Filter by ticket status"
// @Param priority query string false "Filter by priority"
// @Param assignee_id query string false "Filter by assignee ID"
// @Param page query int false "Page number"
// @Param limit query int false "Number of items per page"
// @Success 200 {object} common.APIResponse[common.PaginatedResult[domain.Ticket]] "Get tickets successfully"
// @Failure 400 {object} common.APIResponse[any] "Invalid query parameters"
// @Failure 500 {object} common.APIResponse[any] "Internal server error"
// @Router /tickets [get]
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

// HandleGetTicket godoc
// @Summary Get ticket detail
// @Description Get ticket detail by ID
// @Tags Tickets
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "Ticket ID"
// @Success 200 {object} common.APIResponse[domain.Ticket] "Get ticket successfully"
// @Failure 400 {object} common.APIResponse[any] "Invalid ticket ID"
// @Failure 404 {object} common.APIResponse[any] "Ticket not found"
// @Failure 500 {object} common.APIResponse[any] "Internal server error"
// @Router /tickets/{id} [get]
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

// HandleUpdateStatus godoc
// @Summary Update ticket status
// @Description Update status of a ticket by ID
// @Tags Tickets
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path int true "Ticket ID"
// @Param request body request.UpdateStatusReq true "Update status request"
// @Success 200 {object} common.APIResponse[any] "Ticket status updated successfully"
// @Failure 400 {object} common.APIResponse[any] "Invalid request body or invalid status transition"
// @Failure 404 {object} common.APIResponse[any] "Ticket not found"
// @Failure 500 {object} common.APIResponse[any] "Internal server error"
// @Router /tickets/{id}/status [patch]
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

	currentUser := auth.UserFromContext(c.Request.Context())
	req.AssigneeID = currentUser.UserID

	err = h.ticketService.UpdateTicketStatus(c.Request.Context(), id, req)
	if err != nil {
		HandleError(c, err)
		return
	}

	c.JSON(http.StatusOK, common.SuccessMessageResponse("ticket status updated successfully"))
}
