package common

// SuccessResponseDoc is the common success response schema for Swagger.
// Runtime response still uses APIResponse[T].
type SuccessResponseDoc struct {
	Success bool        `json:"success" example:"true"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty" example:"success"`
}

// SuccessMessageResponseDoc is used for APIs that only return a success message.
// Example: update status successfully.
type SuccessMessageResponseDoc struct {
	Success bool   `json:"success" example:"true"`
	Message string `json:"message" example:"operation completed successfully"`
}

// ErrorResponseDoc is the common error response schema for Swagger.
// Runtime response still uses ErrorResponse(err).
type ErrorResponseDoc struct {
	Success bool     `json:"success" example:"false"`
	Error   ErrorDoc `json:"error"`
}

// ErrorDoc is a generic error schema.
// The code value should be one of the project error codes:
// BAD_REQUEST, VALIDATION_ERROR, INVALID_INPUT, INVALID_REQUEST_BODY,
// INVALID_QUERY_PARAMETERS, RESOURCE_NOT_FOUND, TICKET_NOT_FOUND,
// UNAUTHORIZED, FORBIDDEN, CONFLICT, INVALID_STATUS_TRANSITION,
// INVALID_FLOW_TICKET, EMPTY_REQUEST_BODY, EMPTY_BATCH,
// BATCH_TOO_LARGE, UNSUPPORTED_FILE_FORMAT, INTERNAL_SERVER_ERROR.
type ErrorDoc struct {
	Code    string           `json:"code" example:"ERROR_CODE"`
	Status  int              `json:"status" example:"400"`
	Message string           `json:"message" example:"error message"`
	Details []ErrorDetailDoc `json:"details,omitempty"`
}

// ErrorDetailDoc is used for field-level validation errors.
type ErrorDetailDoc struct {
	Field   string `json:"field" example:"field_name"`
	Message string `json:"message" example:"validation error message"`
}
