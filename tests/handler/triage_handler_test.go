package handler_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"support-ticket.com/internal/dto/request"
	"support-ticket.com/internal/dto/response"
	"support-ticket.com/internal/errmsgs"
	"support-ticket.com/internal/handler"
	testmock "support-ticket.com/tests/mock"
)

func TestTriageHandler_HandleBatchTriageTickets(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tests := []struct {
		name         string
		body         interface{}
		mockSetup    func(*testmock.MockTriageService)
		expectedCode int
	}{
		{
			name: "Success",
			body: request.AIBatchTriageRequest{TicketIDs: []uint{1, 2}},
			mockSetup: func(m *testmock.MockTriageService) {
				m.On("ExecuteBatchTriage", mock.Anything, []uint{1, 2}).Return([]*response.BatchTriageResponseItem{
					{
						TicketID:     1,
						Category:     "IT",
						UrgencyLevel: "high",
					},
					{
						TicketID:     2,
						Category:     "HR",
						UrgencyLevel: "low",
					},
				}, nil)
			},
			expectedCode: http.StatusOK,
		},
		{
			name:         "Invalid JSON Body",
			body:         "invalid json string",
			mockSetup:    func(m *testmock.MockTriageService) {},
			expectedCode: http.StatusBadRequest,
		},
		{
			name: "Empty Ticket IDs",
			body: request.AIBatchTriageRequest{TicketIDs: []uint{}},
			mockSetup: func(m *testmock.MockTriageService) {
				m.On("ExecuteBatchTriage", mock.Anything, []uint{}).Return(([]*response.BatchTriageResponseItem)(nil), errmsgs.ErrEmptyBatch)
			},
			expectedCode: http.StatusBadRequest,
		},
		{
			name: "Ticket Not Found",
			body: request.AIBatchTriageRequest{TicketIDs: []uint{1, 99}},
			mockSetup: func(m *testmock.MockTriageService) {
				m.On("ExecuteBatchTriage", mock.Anything, []uint{1, 99}).Return(([]*response.BatchTriageResponseItem)(nil), errmsgs.ErrTicketNotFound)
			},
			expectedCode: http.StatusNotFound,
		},
		{
			name: "Invalid Flow Ticket (Terminal State)",
			body: request.AIBatchTriageRequest{TicketIDs: []uint{1, 2}},
			mockSetup: func(m *testmock.MockTriageService) {
				m.On("ExecuteBatchTriage", mock.Anything, []uint{1, 2}).Return(([]*response.BatchTriageResponseItem)(nil), errmsgs.ErrInvalidFlowTicket)
			},
			expectedCode: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockSvc := new(testmock.MockTriageService)
			tt.mockSetup(mockSvc)

			h := handler.NewTriageHandler(mockSvc)

			var reqBody []byte
			if str, ok := tt.body.(string); ok {
				reqBody = []byte(str)
			} else {
				reqBody, _ = json.Marshal(tt.body)
			}

			req, _ := http.NewRequest(http.MethodPost, "/ai/tickets/triage:batch", bytes.NewBuffer(reqBody))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()
			_, r := gin.CreateTestContext(w)

			r.POST("/ai/tickets/triage:batch", h.HandleBatchTriageTickets)
			r.ServeHTTP(w, req)

			assert.Equal(t, tt.expectedCode, w.Code)
			mockSvc.AssertExpectations(t)
		})
	}
}
