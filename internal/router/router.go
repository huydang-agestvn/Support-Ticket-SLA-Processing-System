package router

import (
	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"

	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/handler"
	"support-ticket.com/internal/middleware"
)

func InitRouter(
	r *gin.Engine,
	authHandler *handler.AuthHandler,
	eventHandler *handler.TicketEventHandler,
	ticketHandler *handler.TicketHandler,
	authMiddleware *middleware.AuthMiddleware,
	reportHandler *handler.ReportHandler,
	triageHandler *handler.TriageHandler,
) *gin.Engine {

	// Swagger UI reads the OpenAPI contract.
	r.StaticFile("/swagger.yml", "./docs/swagger.yml")

	r.GET("/swagger/*any", ginSwagger.WrapHandler(
		swaggerFiles.Handler,
		ginSwagger.URL("/swagger.yml"),
	))

	api := r.Group("/api/v1")
	{
		authGroup := api.Group("/auth")
		{
			authGroup.POST("/login", authHandler.Login)
		}

		// Agent: import event
		eventGroup := api.Group("/ticket-events")
		{
			eventGroup.POST(
				"/import",
				authMiddleware.RequireAuth(),
				authMiddleware.RequireRole(
					auth.RoleAgent,
					auth.RoleManager,
				),
				eventHandler.ImportEvents,
			)

			eventGroup.GET(
				"/import/logs/:filename",
				authMiddleware.RequireAuth(),
				authMiddleware.RequireRole(
					auth.RoleAgent,
					auth.RoleManager,
				),
				eventHandler.DownloadAuditLog,
			)
		}

		ticketGroup := api.Group("/tickets")
		{
			// Requestor
			ticketGroup.POST(
				"",
				authMiddleware.RequireAuth(),
				authMiddleware.RequireRole(
					auth.RoleRequestor,
					auth.RoleManager,
				),
				ticketHandler.HandleCreateTicket,
			)

			// Requestor / Agent / Manager
			ticketGroup.GET(
				"",
				authMiddleware.RequireAuth(),
				authMiddleware.RequireRole(
					auth.RoleRequestor,
					auth.RoleAgent,
					auth.RoleManager,
				),
				ticketHandler.HandleListTickets,
			)

			// Requestor / Agent / Manager
			ticketGroup.GET(
				"/:id",
				authMiddleware.RequireAuth(),
				authMiddleware.RequireRole(
					auth.RoleRequestor,
					auth.RoleAgent,
					auth.RoleManager,
				),
				ticketHandler.HandleGetTicket,
			)

			// Agent: update status
			ticketGroup.PATCH(
				"/:id/status",
				authMiddleware.RequireAuth(),
				authMiddleware.RequireRole(
					auth.RoleAgent,
					auth.RoleManager,
				),
				ticketHandler.HandleUpdateStatus,
			)
		}

		reportGroup := api.Group("/reports")
		{
			reportGroup.GET(
				"/daily",
				authMiddleware.RequireAuth(),
				authMiddleware.RequireRole(auth.RoleManager),
				reportHandler.GetDaily,
			)
		}

		aiGroup := api.Group("/ai")
		{
			// Agent / Manager: AI Triage a Ticket
			aiGroup.POST(
				"/tickets/:id/triage",
				authMiddleware.RequireAuth(),
				authMiddleware.RequireRole(
					auth.RoleAgent,
					auth.RoleManager,
				),
				triageHandler.HandleTriageTicket,
			)

			// Agent / Manager: Lấy kết quả triage mới nhất của Ticket
			aiGroup.GET(
				"/tickets/:id/triage/latest",
				authMiddleware.RequireAuth(),
				authMiddleware.RequireRole(
					auth.RoleAgent,
					auth.RoleManager,
				),
				triageHandler.HandleGetLatestTriage,
			)
		}
	}
	return r
}
