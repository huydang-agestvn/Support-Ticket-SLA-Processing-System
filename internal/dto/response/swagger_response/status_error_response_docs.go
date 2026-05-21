package swagger_response

// Error response docs
type ErrorDoc struct {
	Code    string `json:"code" example:"ERROR_CODE"`
	Status  int    `json:"status" example:"400"`
	Message string `json:"message" example:"error message"`
}

type ErrorResponseDoc struct {
	Success bool     `json:"success" example:"false"`
	Error   ErrorDoc `json:"error"`
}

// Bad request error response doc
type BadRequestErrorDoc struct {
	Code    string `json:"code" example:"INVALID_REQUEST_BODY"`
	Status  int    `json:"status" example:"400"`
	Message string `json:"message" example:"invalid request body"`
}

type BadRequestResponseDoc struct {
	Success bool               `json:"success" example:"false"`
	Error   BadRequestErrorDoc `json:"error"`
}

// Unauthorized error response doc
type UnauthorizedErrorDoc struct {
	Code    string `json:"code" example:"UNAUTHORIZED"`
	Status  int    `json:"status" example:"401"`
	Message string `json:"message" example:"authorization header is required"`
}

type UnauthorizedResponseDoc struct {
	Success bool                 `json:"success" example:"false"`
	Error   UnauthorizedErrorDoc `json:"error"`
}

// Forbidden error response doc
type ForbiddenErrorDoc struct {
	Code    string `json:"code" example:"FORBIDDEN"`
	Status  int    `json:"status" example:"403"`
	Message string `json:"message" example:"you do not have permission to access this resource"`
}

type ForbiddenResponseDoc struct {
	Success bool              `json:"success" example:"false"`
	Error   ForbiddenErrorDoc `json:"error"`
}

// Ticket not found error response doc
type TicketNotFoundErrorDoc struct {
	Code    string `json:"code" example:"TICKET_NOT_FOUND"`
	Status  int    `json:"status" example:"404"`
	Message string `json:"message" example:"ticket not found"`
}

type TicketNotFoundResponseDoc struct {
	Success bool                   `json:"success" example:"false"`
	Error   TicketNotFoundErrorDoc `json:"error"`
}

// Internal server error response doc
type InternalServerErrorDoc struct {
	Code    string `json:"code" example:"INTERNAL_SERVER_ERROR"`
	Status  int    `json:"status" example:"500"`
	Message string `json:"message" example:"internal server error"`
}

type InternalServerErrorResponseDoc struct {
	Success bool                   `json:"success" example:"false"`
	Error   InternalServerErrorDoc `json:"error"`
}

type ServiceUnavailableErrorDoc struct {
	Code    string `json:"code" example:"AUTH_PROVIDER_UNAVAILABLE"`
	Status  int    `json:"status" example:"503"`
	Message string `json:"message" example:"authentication provider is unavailable"`
}

type ServiceUnavailableResponseDoc struct {
	Success bool                       `json:"success" example:"false"`
	Error   ServiceUnavailableErrorDoc `json:"error"`
}
