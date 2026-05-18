package integration

import (
	"context"
	"fmt"
	"time"

	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
	gormpostgres "gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"support-ticket.com/internal/migration"
)

type TestEnv struct {
	Container *postgres.PostgresContainer
	DB        *gorm.DB
}

func SetupTestEnv(ctx context.Context) (*TestEnv, error) {
	dbName := "ticket_sla_test"
	dbUser := "postgres"
	dbPassword := "postgres"

	pgContainer, err := postgres.Run(ctx,
		"postgres:16.2-alpine",
		postgres.WithDatabase(dbName),
		postgres.WithUsername(dbUser),
		postgres.WithPassword(dbPassword),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).WithStartupTimeout(10*time.Second)),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to start postgres container: %w", err)
	}

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		return nil, fmt.Errorf("failed to get connection string: %w", err)
	}

	db, err := gorm.Open(gormpostgres.Open(connStr), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to db: %w", err)
	}

	// Run migrations to setup schema
	if err := migration.RunMigrations(db); err != nil {
		return nil, fmt.Errorf("failed to run migrations: %w", err)
	}

	return &TestEnv{
		Container: pgContainer,
		DB:        db,
	}, nil
}

func (env *TestEnv) Teardown(ctx context.Context) error {
	if env.Container != nil {
		return env.Container.Terminate(ctx)
	}
	return nil
}
