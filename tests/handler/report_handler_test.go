package handler_test

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"support-ticket.com/internal/handler"
	domain "support-ticket.com/internal/model"
	testmock "support-ticket.com/tests/mock"
)

func TestReportHandler_GetDaily(t *testing.T) {
	gin.SetMode(gin.TestMode)
	now := time.Now()

	tests := []struct {
		name         string
		dateQuery    string
		mockSetup    func(*testmock.MockReportService)
		expectedCode int
	}{
		{
			name:      "Success",
			dateQuery: now.Format("2006-01-02"),
			mockSetup: func(m *testmock.MockReportService) {
				date, _ := time.Parse("2006-01-02", now.Format("2006-01-02"))
				m.On("GetReport", date).Return(&domain.TicketReport{ReportDate: date}, nil)
			},
			expectedCode: http.StatusOK,
		},
		{
			name:         "Invalid Date Format",
			dateQuery:    "invalid-date",
			mockSetup:    func(m *testmock.MockReportService) {},
			expectedCode: http.StatusBadRequest,
		},
		{
			name:      "Report Not Found",
			dateQuery: now.Format("2006-01-02"),
			mockSetup: func(m *testmock.MockReportService) {
				date, _ := time.Parse("2006-01-02", now.Format("2006-01-02"))
				m.On("GetReport", date).Return((*domain.TicketReport)(nil), errors.New("report not found"))
			},
			expectedCode: http.StatusNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockSvc := new(testmock.MockReportService)
			tt.mockSetup(mockSvc)

			h := handler.NewReportHandler(mockSvc)

			req, _ := http.NewRequest(http.MethodGet, "/report?date="+tt.dateQuery, nil)
			w := httptest.NewRecorder()
			c, _ := gin.CreateTestContext(w)
			c.Request = req

			h.GetDaily(c)

			assert.Equal(t, tt.expectedCode, w.Code)
			mockSvc.AssertExpectations(t)
		})
	}
}
