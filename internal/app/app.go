package app

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"support-ticket.com/internal/ai"
	aifactory "support-ticket.com/internal/ai/factory"
	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/config"
	"support-ticket.com/internal/cron"
	"support-ticket.com/internal/handler"
	"support-ticket.com/internal/middleware"
	"support-ticket.com/internal/migration"
	"support-ticket.com/internal/repository"
	"support-ticket.com/internal/router"
	"support-ticket.com/internal/seeding"
	"support-ticket.com/internal/service"
)

type App struct {
	cfg       *config.Config
	db        *gorm.DB
	router    *gin.Engine
	scheduler *cron.Scheduler
}

func NewApp() *App {
	return &App{}
}

func (a *App) Run() error {
	// 1. Load Configuration
	a.cfg = config.LoadConfig()

	// 2. Initialize Database
	if err := a.initDB(); err != nil {
		return err
	}

	sqlDB, err := a.db.DB()
	if err == nil {
		defer func() {
			if closeErr := sqlDB.Close(); closeErr != nil {
				slog.ErrorContext(context.Background(), "failed to close database connection", slog.Any("error", closeErr))
			}
		}()
	}

	// 3. Run Migrations
	if err := migration.RunMigrations(a.db); err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	// 4. Run Seeding
	if err := seeding.SeedAIEvaluationCases(a.db); err != nil {
		return fmt.Errorf("failed to run seeding: %w", err)
	}

	// 5. Setup Dependency Injection
	a.setupDependencies()

	// 5. Start Cron Scheduler
	if err := a.scheduler.Start(); err != nil {
		return fmt.Errorf("failed to start scheduler: %w", err)
	}
	defer a.scheduler.Stop()

	// 6. Start HTTP Server
	return a.startServer()
}

func (a *App) initDB() error {
	var err error
	a.db, err = a.cfg.GetDatabase()
	if err != nil {
		return fmt.Errorf("failed to initialize database: %w", err)
	}
	slog.InfoContext(context.Background(), "database connected", slog.String("db_host", a.cfg.DBHost), slog.Int("db_port", a.cfg.DBPort), slog.String("db_name", a.cfg.DBName))
	return nil
}

func (a *App) setupDependencies() {
	aiAdapter := aifactory.NewAdapterFromConfig(a.cfg)

	_ = aiAdapter

	ticketRepo := repository.NewTicketRepository(a.db)
	eventRepo := repository.NewTicketEventRepository(a.db)
	reportRepo := repository.NewReportRepository(a.db)
	triageRepo := repository.NewTriageRepository(a.db)
	evaluationRepo := repository.NewEvaluationRepository(a.db)

	auditLogger, err := service.NewMinIOAuditLogger(
		a.cfg.MinioEndpoint,
		a.cfg.MinioAccessKey,
		a.cfg.MinioSecretKey,
		a.cfg.MinioUseSSL,
		a.cfg.MinioBucketName,
	)
	if err != nil {
		slog.ErrorContext(context.Background(), "failed to initialize audit logger", slog.Any("error", err))
	}

	kbRepo := repository.NewKnowledgeBaseRepository(a.db)
	embeddingClient := ai.NewEmbeddingClient(a.cfg.EmbeddingServiceURL, a.cfg.EmbeddingModel, a.cfg.AITimeoutSecs)

	ticketService := service.NewTicketService(ticketRepo, eventRepo)
	eventService := service.NewTicketEventService(eventRepo, ticketRepo, auditLogger)
	reportService := service.NewReportService(reportRepo)
	triageService := service.NewTriageService(ticketRepo, reportRepo, triageRepo, kbRepo, aiAdapter, embeddingClient, a.cfg)
	evaluationService := service.NewEvaluationService(evaluationRepo, reportRepo, aiAdapter)

	ticketHandler := handler.NewTicketHandler(ticketService)
	eventHandler := handler.NewTicketEventHandler(eventService)
	reportHander := handler.NewReportHandler(reportService)
	triageHandler := handler.NewTriageHandler(triageService)
	evaluationHandler := handler.NewEvaluationHandler(evaluationService)

	keycloakClient := service.NewClient(
		a.cfg.KeycloakTokenURL,
		a.cfg.KeycloakClientID,
		a.cfg.KeycloakClientSecret,
	)

	authService := service.NewAuthService(keycloakClient)
	authHandler := handler.NewAuthHandler(authService)

	authenticator := auth.NewKeycloakAuthenticator(
		a.cfg.KeycloakIssuer,
		a.cfg.KeycloakClientID,
		a.cfg.KeycloakJWKSURL,
	)

	authMiddleware := middleware.NewAuthMiddleware(authenticator)

	r := gin.New()
	a.router = router.InitRouter(
		r,
		authHandler,
		eventHandler,
		ticketHandler,
		authMiddleware,
		reportHander,
		triageHandler,
		evaluationHandler,
	)

	// 6. Initialize EmailService and Cron Scheduler
	emailService := service.NewEmailService(a.cfg)
	a.scheduler = cron.NewScheduler(reportService, emailService)
}

func (a *App) startServer() error {
	serverPort := a.cfg.ServerPort
	if serverPort == 0 {
		serverPort = 8080
	}
	addr := fmt.Sprintf(":%d", serverPort)

	slog.InfoContext(context.Background(), "worker pool size", slog.Int("worker_pool_size", a.cfg.WorkerPoolSize))
	slog.InfoContext(context.Background(), "starting HTTP server on", slog.String("addr", addr))

	return a.router.Run(addr)
}
