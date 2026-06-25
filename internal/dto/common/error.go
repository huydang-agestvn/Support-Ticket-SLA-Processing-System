package common

import "net/http"

const (
	ErrCodeBadRequest            = "BAD_REQUEST"
	ErrCodeValidation            = "VALIDATION_ERROR"
	ErrCodeInvalidInput          = "INVALID_INPUT"
	ErrCodeInvalidBody           = "INVALID_REQUEST_BODY"
	ErrCodeInvalidQuery          = "INVALID_QUERY_PARAMETERS"
	ErrCodeNotFound              = "RESOURCE_NOT_FOUND"
	ErrCodeTicketNotFound        = "TICKET_NOT_FOUND"
	ErrCodeTriageNotFound        = "TRIAGE_RESULT_NOT_FOUND"
	ErrCodeUnauthorized          = "UNAUTHORIZED"
	ErrCodeForbidden             = "FORBIDDEN"
	ErrCodeConflict              = "CONFLICT"
	ErrCodeInvalidTransition     = "INVALID_STATUS_TRANSITION"
	ErrCodeInvalidFlow           = "INVALID_FLOW_TICKET"
	ErrCodeEmptyBody             = "EMPTY_REQUEST_BODY"
	ErrCodeEmptyBatch            = "EMPTY_BATCH"
	ErrCodeBatchTooLarge         = "BATCH_TOO_LARGE"
	ErrCodeUnsupportedFileFormat = "UNSUPPORTED_FILE_FORMAT"
	ErrCodeInternal              = "INTERNAL_SERVER_ERROR"
	ErrCodeTicketContentBlocked  = "TICKET_CONTENT_BLOCKED"
)

type Error struct {
	Code    string        `json:"code"`
	Message string        `json:"message"`
	Details []ErrorDetail `json:"details,omitempty"`
}

func (e *Error) Error() string {
	return e.Message
}

type ErrorDetail struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

func NewBadRequest(code, message string, details ...ErrorDetail) *Error {
	return &Error{
		Code:    code,
		Message: message,
		Details: details,
	}
}

func NewValidation(message string, details []ErrorDetail) *Error {
	return &Error{
		Code:    ErrCodeValidation,
		Message: message,
		Details: details,
	}
}

func NewNotFound(code, message string) *Error {
	return &Error{
		Code:    code,
		Message: message,
	}
}

func NewUnauthorized(code, message string) *Error {
	return &Error{
		Code:    code,
		Message: message,
	}
}

func NewForbidden(code, message string) *Error {
	return &Error{
		Code:    code,
		Message: message,
	}
}

func NewConflict(code, message string) *Error {
	return &Error{
		Code:    code,
		Message: message,
	}
}

func NewInternal(message string) *Error {
	return &Error{
		Code:    ErrCodeInternal,
		Message: message,
	}
}

// HTTPStatusFromCode maps an error code to an HTTP status.
func HTTPStatusFromCode(code string) int {
	switch code {
	case ErrCodeInternal:
		return http.StatusInternalServerError
	case ErrCodeNotFound, ErrCodeTicketNotFound, ErrCodeTriageNotFound:
		return http.StatusNotFound
	case ErrCodeUnauthorized:
		return http.StatusUnauthorized
	case ErrCodeForbidden:
		return http.StatusForbidden
	case ErrCodeConflict:
		return http.StatusConflict
	case ErrCodeValidation, ErrCodeTicketContentBlocked, ErrCodeBadRequest, ErrCodeInvalidInput, ErrCodeInvalidBody, ErrCodeInvalidQuery, ErrCodeEmptyBody, ErrCodeEmptyBatch, ErrCodeBatchTooLarge, ErrCodeUnsupportedFileFormat:
		return http.StatusBadRequest
	default:
		return http.StatusBadRequest
	}
}
