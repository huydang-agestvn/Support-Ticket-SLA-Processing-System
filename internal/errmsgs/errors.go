package errmsgs

import (
	"support-ticket.com/internal/dto/common"
)

var (
	ErrNotFound                 = common.NewNotFound(common.ErrCodeNotFound, "resource not found")
	ErrTicketNotFound           = common.NewNotFound(common.ErrCodeTicketNotFound, "ticket not found")
	ErrTriageNotFound           = common.NewNotFound(common.ErrCodeTriageNotFound, "triage result not found for this ticket")
	ErrUnauthorized             = common.NewUnauthorized(common.ErrCodeUnauthorized, "unauthorized")
	ErrForbidden                = common.NewForbidden(common.ErrCodeForbidden, "forbidden")
	ErrConflict                 = common.NewConflict(common.ErrCodeConflict, "conflict")
	ErrInvalidStatusTransition  = common.NewBadRequest(common.ErrCodeInvalidTransition, "invalid status transition")
	ErrInvalidInput             = common.NewBadRequest(common.ErrCodeInvalidInput, "invalid input")
	ErrInvalidFlowTicket        = common.NewBadRequest(common.ErrCodeInvalidFlow, "invalid flow ticket")
	ErrEmptyBody                = common.NewBadRequest(common.ErrCodeEmptyBody, "request body is empty")
	ErrEmptyBatch               = common.NewBadRequest(common.ErrCodeEmptyBatch, "batch is empty")
	ErrBatchTooLarge            = common.NewBadRequest(common.ErrCodeBatchTooLarge, "batch size exceeds maximum allowed")
	ErrUnsupportedFileFormat    = common.NewBadRequest(common.ErrCodeUnsupportedFileFormat, "unsupported file format: only json and csv are accepted")
	ErrUnauthorizedToViewTicket = common.NewUnauthorized(common.ErrCodeUnauthorized, "unauthorized to view this ticket")
	ErrInternal                 = common.NewInternal("internal server error")
	ErrValidation               = common.NewBadRequest(common.ErrCodeValidation, "ticket validation failed")
	ErrTicketResolved           = common.NewBadRequest(common.ErrCodeInvalidInput, "ticket already resolved and does not require AI triage")
	ErrTicketOverdue            = common.NewBadRequest(common.ErrCodeInvalidInput, "ticket is overdue and cannot be triaged")
	ErrTicketDescriptionTooShort = common.NewBadRequest(common.ErrCodeInvalidInput, "ticket description is too short for meaningful AI triage (minimum 10 characters required)")
)
