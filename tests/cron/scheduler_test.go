package cron_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	testifymock "github.com/stretchr/testify/mock"
	"support-ticket.com/internal/cron"
	"support-ticket.com/tests/mock"
)

func TestNewScheduler(t *testing.T) {
	mockSvc := new(mock.MockReportService)
	scheduler := cron.NewScheduler(mockSvc)

	assert.NotNil(t, scheduler)
	assert.NotNil(t, scheduler.GetCron())
	assert.Equal(t, mockSvc, scheduler.GetReportService())
}

func TestScheduler_StartStop(t *testing.T) {
	mockSvc := new(mock.MockReportService)
	scheduler := cron.NewScheduler(mockSvc)

	// Verify Start succeeds and schedules our task
	err := scheduler.Start()
	assert.NoError(t, err)
	
	// Entries should have exactly 1 scheduled job
	entries := scheduler.GetCron().Entries()
	assert.Len(t, entries, 1)

	// Stop scheduler
	scheduler.Stop()
}

func TestScheduler_JobExecution(t *testing.T) {
	mockSvc := new(mock.MockReportService)
	// We want to verify that when the job runs, it calls reportSvc.GenerateReport
	// In the real code, AddFunc adds a func that runs asynchronously.
	// We can manually run the func registered in the cron entry to verify its logic.
	
	scheduler := cron.NewScheduler(mockSvc)
	err := scheduler.Start()
	assert.NoError(t, err)
	defer scheduler.Stop()

	entries := scheduler.GetCron().Entries()
	assert.Len(t, entries, 1)

	// Extract the registered job function
	jobFunc := entries[0].WrappedJob

	// Mock expectations: We expect GenerateReport to be called
	mockSvc.On("GenerateReport", testifymock.AnythingOfType("time.Time")).Return(nil, assert.AnError)

	// Manually execute the job
	jobFunc.Run()

	// Assert expectations
	mockSvc.AssertExpectations(t)
}

