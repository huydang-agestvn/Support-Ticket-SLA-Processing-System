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
	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/handler"
	"support-ticket.com/internal/model"
	testmock "support-ticket.com/tests/mock"
)

func TestTicketHandler_HandleGetTicket(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tests := []struct {
		name         string
		ticketID     string
		mockSetup    func(*testmock.MockTicketService)
		expectedCode int
	}{
		{
			name:     "Success",
			ticketID: "1",
			mockSetup: func(m *testmock.MockTicketService) {
				m.On("FindById", mock.Anything, uint(1)).Return(&model.Ticket{ID: 1, Title: "Test"}, nil)
			},
			expectedCode: http.StatusOK,
		},
		{
			name:         "Invalid ID",
			ticketID:     "abc",
			mockSetup:    func(m *testmock.MockTicketService) {},
			expectedCode: http.StatusBadRequest,
		},
		{
			name:     "Not Found",
			ticketID: "99",
			mockSetup: func(m *testmock.MockTicketService) {
				m.On("FindById", mock.Anything, uint(99)).Return((*model.Ticket)(nil), errors.New("ticket not found"))
			},
			expectedCode: http.StatusInternalServerError,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockSvc := new(testmock.MockTicketService)
			tt.mockSetup(mockSvc)

			h := handler.NewTicketHandler(mockSvc)

			req, _ := http.NewRequest(http.MethodGet, "/tickets/"+tt.ticketID, nil)
			w := httptest.NewRecorder()
			_, r := gin.CreateTestContext(w)
			
			r.Use(func(c *gin.Context) {
				fakeUser := auth.UserPrincipal{UserID: "req-1"}
				ctx := auth.WithUser(c.Request.Context(), fakeUser)
				c.Request = c.Request.WithContext(ctx)
				c.Next()
			})

			r.GET("/tickets/:id", h.HandleGetTicket)
			r.ServeHTTP(w, req)

			assert.Equal(t, tt.expectedCode, w.Code)
			mockSvc.AssertExpectations(t)
		})
	}
}

func TestTicketHandler_HandleCreateTicket(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tests := []struct {
		name         string
		body         interface{}
		mockSetup    func(*testmock.MockTicketService)
		expectedCode int
	}{
		{
			name: "Success",
			body: request.CreateTicketReq{Title: "Test", Description: "Test desc"},
			mockSetup: func(m *testmock.MockTicketService) {
				m.On("Create", mock.Anything, mock.AnythingOfType("request.CreateTicketReq")).Return(&model.Ticket{ID: 1}, nil)
			},
			expectedCode: http.StatusCreated,
		},
		{
			name:         "Invalid Body",
			body:         "invalid json",
			mockSetup:    func(m *testmock.MockTicketService) {},
			expectedCode: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockSvc := new(testmock.MockTicketService)
			tt.mockSetup(mockSvc)

			h := handler.NewTicketHandler(mockSvc)

			var reqBody []byte
			if str, ok := tt.body.(string); ok {
				reqBody = []byte(str)
			} else {
				reqBody, _ = json.Marshal(tt.body)
			}

			req, _ := http.NewRequest(http.MethodPost, "/tickets", bytes.NewBuffer(reqBody))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()
			_, r := gin.CreateTestContext(w)

			r.Use(func(c *gin.Context) {
				fakeUser := auth.UserPrincipal{UserID: "req-1"}
				ctx := auth.WithUser(c.Request.Context(), fakeUser)
				c.Request = c.Request.WithContext(ctx)
				c.Next()
			})

			r.POST("/tickets", h.HandleCreateTicket)
			r.ServeHTTP(w, req)

			assert.Equal(t, tt.expectedCode, w.Code)
			mockSvc.AssertExpectations(t)
		})
	}
}
