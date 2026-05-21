package integration

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	domain "support-ticket.com/internal/model"
	"support-ticket.com/internal/repository"
)

func TestTicketRepositoryIntegration(t *testing.T) {
	ctx := context.Background()
	env, err := SetupTestEnv(ctx)
	require.NoError(t, err)
	defer env.Teardown(ctx)

	repo := repository.NewTicketRepository(env.DB)

	t.Run("TestCreateAndFindById", func(t *testing.T) {
		dueAt := time.Now().Add(2 * time.Hour).Truncate(time.Millisecond)
		createdAt := time.Now().Truncate(time.Millisecond)

		ticket := &domain.Ticket{
			RequestorID: "user1",
			Title:       "Integration Test Ticket",
			Description: "Testing the real DB",
			Priority:    domain.PriorityHigh,
			Status:      domain.StatusNew,
			SLADueAt:    &dueAt,
			CreatedAt:   createdAt,
		}

		err := repo.Create(ctx, ticket)
		assert.NoError(t, err)
		assert.NotZero(t, ticket.ID)

		// Find it
		found, err := repo.FindById(ctx, ticket.ID)
		assert.NoError(t, err)
		require.NotNil(t, found)
		assert.Equal(t, ticket.Title, found.Title)
		assert.Equal(t, ticket.RequestorID, found.RequestorID)
		assert.Equal(t, ticket.Status, found.Status)
		assert.True(t, ticket.SLADueAt.Equal(*found.SLADueAt))
		assert.True(t, ticket.CreatedAt.Equal(found.CreatedAt))
	})
}
