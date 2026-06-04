package main

import (
	"context"
	"log/slog"

	"support-ticket.com/internal/app"
)

// @title Support Ticket SLA Processing System API
// @version 1.0
// @description REST API for support ticket SLA processing system.
// @host localhost:8080
// @BasePath /api/v1

// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
func main() {
	application := app.NewApp()

	if err := application.Run(); err != nil {
		slog.ErrorContext(context.Background(), "application failed to start", slog.Any("error", err))
	}
}
