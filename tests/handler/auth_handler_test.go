package handler_test

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/handler"
	testmock "support-ticket.com/tests/mock"
)

func TestAuthHandler_Login(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tests := []struct {
		name         string
		body         interface{}
		mockSetup    func(*testmock.MockAuthService)
		expectedCode int
	}{
		{
			name: "Success",
			body: request.LoginRequest{Username: "user", Password: "pwd"},
			mockSetup: func(m *testmock.MockAuthService) {
				m.On("Login", request.LoginRequest{Username: "user", Password: "pwd"}).Return(&response.LoginResponse{AccessToken: "token"}, nil)
			},
			expectedCode: http.StatusOK,
		},
		{
			name:         "Invalid Body",
			body:         "invalid json",
			mockSetup:    func(m *testmock.MockAuthService) {},
			expectedCode: http.StatusBadRequest,
		},
		{
			name: "Login Failed",
			body: request.LoginRequest{Username: "user", Password: "wrong"},
			mockSetup: func(m *testmock.MockAuthService) {
				m.On("Login", mock.Anything).Return((*response.LoginResponse)(nil), errors.New("invalid credentials"))
			},
			expectedCode: http.StatusInternalServerError, 
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockSvc := new(testmock.MockAuthService)
			tt.mockSetup(mockSvc)

			h := handler.NewAuthHandler(mockSvc)

			var reqBody []byte
			if str, ok := tt.body.(string); ok {
				reqBody = []byte(str)
			} else {
				reqBody, _ = json.Marshal(tt.body)
			}

			req, _ := http.NewRequest(http.MethodPost, "/login", bytes.NewBuffer(reqBody))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()
			c, _ := gin.CreateTestContext(w)
			c.Request = req

			h.Login(c)

			assert.Equal(t, tt.expectedCode, w.Code)
			mockSvc.AssertExpectations(t)
		})
	}
}
