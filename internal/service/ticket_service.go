package service

import (
	"context"
	"fmt"
	"log/slog"
	"math"
	"strings"
	"time"

	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/errmsgs"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/repository"
)

type TicketService interface {
	Create(ctx context.Context, req request.CreateTicketReq) (*model.Ticket, error)
	FindById(ctx context.Context, id uint) (*model.Ticket, error)
	FindAll(ctx context.Context, filter request.TicketFilter, paging common.PaginationQuery) (*common.PaginatedResult[model.Ticket], error)
	UpdateTicketStatus(ctx context.Context, id uint, req request.UpdateStatusReq) error
}

type ticketServiceImpl struct {
	repo          repository.TicketRepository
	eventRepo     repository.TicketEventRepository
	contentSafety ContentSafetyService
}

func NewTicketService(repo repository.TicketRepository, eventRepo repository.TicketEventRepository) TicketService {
	return &ticketServiceImpl{
		repo:          repo,
		eventRepo:     eventRepo,
		contentSafety: NewContentSafetyService(),
	}
}

func (s *ticketServiceImpl) Create(ctx context.Context, req request.CreateTicketReq) (*model.Ticket, error) {
	now := time.Now()

	if s.contentSafety != nil {
		safetyResult := s.contentSafety.CheckTicket(req.Title, req.Description)
		if safetyResult.Blocked {
			logBlockedTicket(ctx, 0, req.RequestorID, safetyResult, "create_ticket")
			return nil, contentSafetyBlockedError(safetyResult)
		}
	}

	slog.InfoContext(ctx, "initiating ticket creation",
		slog.String("requestor_id", req.RequestorID),
		slog.String("priority", string(req.Priority)),
	)

	ticket := &model.Ticket{
		RequestorID:     req.RequestorID,
		Title:           req.Title,
		Description:     req.Description,
		Priority:        req.Priority,
		Category:        req.Category,
		SLADueAt:        req.SlaDueAt,
		Status:          model.StatusNew,
		TicketCreatedAt: now,
		AuditModel: model.AuditModel{
			CreatedAt: now,
		},
	}

	if err := ticket.Validate(); err != nil {
		slog.WarnContext(ctx, "failed to validate ticket data",
			slog.String("requestor_id", req.RequestorID),
			slog.Any("validation_error", err),
		)
		return nil, fmt.Errorf("invalid ticket data: %w", err)
	}

	if err := s.repo.Create(ctx, ticket); err != nil {
		slog.ErrorContext(ctx, "failed to save ticket to database",
			slog.String("requestor_id", req.RequestorID),
			slog.Any("db_error", err),
		)
		return nil, fmt.Errorf("failed to create ticket in db: %w", err)
	}

	slog.InfoContext(ctx, "ticket created successfully",
		slog.Uint64("ticket_id", uint64(ticket.ID)),
		slog.String("status", string(ticket.Status)),
		slog.Duration("duration", time.Since(now)),
	)

	return ticket, nil
}

func (s *ticketServiceImpl) FindById(ctx context.Context, id uint) (*model.Ticket, error) {
	currentUser := auth.UserFromContext(ctx)
	userId := currentUser.UserID
	ticket, err := s.repo.FindById(ctx, id)
	if err != nil {
		slog.ErrorContext(ctx, "failed to get ticket from db",
			slog.Uint64("ticket_id", uint64(id)),
			slog.Any("db_error", err),
		)
		return nil, fmt.Errorf("failed to get ticket from db: %w", err)
	}

	if ticket == nil {
		slog.WarnContext(ctx, "ticket not found",
			slog.Uint64("ticket_id", uint64(id)),
		)
		return nil, errmsgs.ErrTicketNotFound
	}

	if userId != ticket.RequestorID && currentUser.HasAnyRole(auth.RoleRequestor) {
		return nil, errmsgs.ErrUnauthorizedToViewTicket
	}
	slog.InfoContext(ctx, "ticket found and authorized",
		slog.String("user_id", userId),
		slog.String("requestor_id", ticket.RequestorID),
	)

	return ticket, nil
}

func (s *ticketServiceImpl) FindAll(ctx context.Context, filter request.TicketFilter, paging common.PaginationQuery) (*common.PaginatedResult[model.Ticket], error) {
	limit := paging.GetLimit()
	offset := paging.GetOffset()
	page := paging.GetPage()

	tickets, total, err := s.repo.FindAll(ctx, filter, offset, limit)
	if err != nil {
		slog.ErrorContext(ctx, "failed to list tickets",
			slog.Any("db_error", err),
		)
		return nil, fmt.Errorf("failed to list tickets: %w", err)
	}
	if tickets == nil {
		tickets = []model.Ticket{}
	}

	totalPages := int(math.Ceil(float64(total) / float64(limit)))

	slog.InfoContext(ctx, "ticket fetched successfully")

	result := &common.PaginatedResult[model.Ticket]{
		Items:      tickets,
		Total:      total,
		Page:       page,
		Limit:      limit,
		TotalPages: totalPages,
	}

	return result, nil
}

func (s *ticketServiceImpl) UpdateTicketStatus(ctx context.Context, id uint, req request.UpdateStatusReq) error {
	ticket, err := s.repo.FindById(ctx, id)
	if err != nil {
		slog.ErrorContext(ctx, "failed to get ticket for status update",
			slog.Uint64("ticket_id", uint64(id)),
			slog.Any("db_error", err),
		)
		return fmt.Errorf("failed to get ticket: %w", err)
	}
	if ticket == nil {
		slog.WarnContext(ctx, "ticket not found for status update",
			slog.Uint64("ticket_id", uint64(id)),
		)
		return errmsgs.ErrTicketNotFound
	}

	if ticket.Status == model.StatusNew && req.Status == model.StatusAssigned {
		currentUser := auth.UserFromContext(ctx)
		req.AssigneeID = strings.TrimSpace(currentUser.UserID)
	}

	if err := ticket.ValidateStatusTransition(req.Status, req.AssigneeID, time.Now()); err != nil {
		slog.WarnContext(ctx, "invalid ticket status transition",
			slog.Uint64("ticket_id", uint64(id)),
			slog.String("from_status", string(ticket.Status)),
			slog.String("to_status", string(req.Status)),
			slog.Any("validation_error", err),
		)
		return err
	}

	event := &model.TicketEvent{
		TicketID:   ticket.ID,
		AssigneeID: ticket.AssigneeID,
		FromStatus: ticket.Status,
		ToStatus:   req.Status,
		CreatedAt:  time.Now(),
	}
	event.Validate()

	ticket.Status = req.Status

	if err := s.repo.UpdateStatusWithEvent(ctx, ticket, event); err != nil {
		slog.ErrorContext(ctx, "failed to update ticket status in database",
			slog.Uint64("ticket_id", uint64(id)),
			slog.String("to_status", string(req.Status)),
			slog.Any("db_error", err),
		)
		return fmt.Errorf("failed to update ticket status: %w", err)
	}

	slog.InfoContext(ctx, "ticket status updated successfully",
		slog.Uint64("ticket_id", uint64(id)),
		slog.String("from_status", string(event.FromStatus)),
		slog.String("to_status", string(req.Status)),
	)

	return nil
}
