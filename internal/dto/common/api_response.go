package common

type APIResponse[T any] struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
	Data    T      `json:"data,omitempty"`
	Error   *Error `json:"error,omitempty"`
}

func SuccessResponse[T any](data T) APIResponse[T] {
	return APIResponse[T]{
		Success: true,
		Data:    data,
	}
}

func SuccessMessageResponse(message string) APIResponse[any] {
	return APIResponse[any]{
		Success: true,
		Message: message,
	}
}

func ErrorResponse(err *Error) APIResponse[any] {
	return APIResponse[any]{
		Success: false,
		Error:   err,
	}
}
