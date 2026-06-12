package service

import (
	"context"
	"fmt"
	"log/slog"
	"sort"
	"strings"
	"time"

	"support-ticket.com/internal/auth"
	"support-ticket.com/internal/config"
	"support-ticket.com/internal/dto/common"
	"support-ticket.com/internal/errmsgs"
	"support-ticket.com/internal/model"
	"support-ticket.com/internal/repository"
	"support-ticket.com/internal/worker"
)

type TicketEventService interface {
	Import(ctx context.Context, events []model.TicketEvent) (model.BatchImportResult, error)
	GetAuditLogPath(filename string) (string, error)
}

type ticketEventService struct {
	eventRepo   repository.TicketEventRepository
	ticketRepo  repository.TicketRepository
	auditLogger AuditLogger
}

func NewTicketEventService(eventRepo repository.TicketEventRepository, ticketRepo repository.TicketRepository, auditLogger AuditLogger) TicketEventService {
	return &ticketEventService{
		eventRepo:   eventRepo,
		ticketRepo:  ticketRepo,
		auditLogger: auditLogger,
	}
}

type rejectedEventWithReason struct {
	Event  model.TicketEvent
	Reason string
}

type updateJob struct {
	TicketID    uint
	Status      model.TicketStatus
	AssigneeID  string
	CreatedAt   time.Time
	ResolvedAt  *time.Time
	CancelledAt *time.Time
}

var maxBatchSize = config.GetBatchSize("MAX_BATCH_SIZE")

type parsedEvent struct {
	Event model.TicketEvent
	Err   error // nil = valid
}

type ticketWorkerJob struct {
	TicketID uint
	Events   []model.TicketEvent
}

type ticketJobResult struct {
	AcceptedEvents []model.TicketEvent
	RejectedEvents []model.TicketEvent
	RejectedError  string
	DuplicateCount int
	FinalUpdateJob *updateJob
}

type importMetadata struct {
	existingTickets         map[uint]bool
	existingTicketStatuses  map[uint]model.TicketStatus
	ticketCreatedAt         map[uint]time.Time
	existingDBEvents        map[string]bool
	existingTicketAssignees map[uint]string
}


func (s *ticketEventService) buildParsedEvents(events []model.TicketEvent) ([]parsedEvent, error) {
	if len(events) == 0 {
		return nil, errmsgs.ErrEmptyBatch
	}
	if len(events) > maxBatchSize {
		return nil, common.NewBadRequest(
			common.ErrCodeBatchTooLarge,
			fmt.Sprintf("batch size exceeds maximum allowed (limit: %d, got: %d)", maxBatchSize, len(events)),
		)
	}
	parsed := make([]parsedEvent, len(events))
	for i, e := range events {
		parsed[i] = parsedEvent{Event: e, Err: e.Validate()}
	}
	return parsed, nil
}

func (s *ticketEventService) Import(ctx context.Context, events []model.TicketEvent) (model.BatchImportResult, error) {
	slog.InfoContext(ctx, "initiating batch import",
		slog.Int("total_events", len(events)),
	)

	parsedEvents, err := s.buildParsedEvents(events)
	if err != nil {
		return model.BatchImportResult{}, err
	}

	workerJobs, rejectedEvents, rejectedCount, ticketIDs, eventKeys := s.filterAndGroupEvents(parsedEvents)

	meta, err := s.fetchMetadata(ctx, ticketIDs, eventKeys)
	if err != nil {
		slog.ErrorContext(ctx, "failed to fetch metadata for import",
			slog.Any("error", err),
		)
		return model.BatchImportResult{}, err
	}

	results := worker.Run(workerJobs, func(job ticketWorkerJob) ticketJobResult {
		return s.simulateTicketFSM(job, meta)
	})

	finalResult := model.BatchImportResult{
		RejectedCount: rejectedCount,
	}

	var allRejected []rejectedEventWithReason

	for errStr, evs := range rejectedEvents {
		for _, ev := range evs {
			allRejected = append(allRejected, rejectedEventWithReason{
				Event:  ev,
				Reason: errStr,
			})
		}
	}

	var eventsToInsert []model.TicketEvent
	var finalUpdates []updateJob

	for _, res := range results {
		finalResult.DuplicateCount += res.DuplicateCount

		if res.RejectedError != "" {
			finalResult.RejectedCount += len(res.RejectedEvents)
			for _, ev := range res.RejectedEvents {
				allRejected = append(allRejected, rejectedEventWithReason{
					Event:  ev,
					Reason: res.RejectedError,
				})
			}
		}

		if len(res.AcceptedEvents) > 0 {
			eventsToInsert = append(eventsToInsert, res.AcceptedEvents...)
			finalResult.AcceptedCount += len(res.AcceptedEvents)
		}

		if res.FinalUpdateJob != nil {
			finalUpdates = append(finalUpdates, *res.FinalUpdateJob)
		}
	}

	err = s.applyDBResults(ctx, eventsToInsert, finalUpdates)
	if err != nil {
		slog.ErrorContext(ctx, "failed to apply import db results",
			slog.Any("error", err),
		)
		return model.BatchImportResult{}, err
	}

	currentUser := auth.UserFromContext(ctx)
	if finalResult.RejectedCount > 0 {
		records := make([]AuditLogRecord, len(allRejected))
		for i, r := range allRejected {
			records[i] = AuditLogRecord{
				TicketID:   r.Event.TicketID,
				FromStatus: string(r.Event.FromStatus),
				ToStatus:   string(r.Event.ToStatus),
				AssigneeID: r.Event.AssigneeID,
				CreatedAt:  r.Event.CreatedAt,
				Reason:     r.Reason,
			}
		}
		fileName, err := s.auditLogger.WriteAuditLog(records, currentUser.UserID)
		if err != nil {
			slog.ErrorContext(ctx, "failed to write audit log for rejected events",
				slog.Any("error", err),
			)
			return model.BatchImportResult{}, fmt.Errorf("failed to write audit log: %w", err)
		}
		finalResult.AuditLogFile = fileName
	}

	slog.InfoContext(ctx, "batch import completed",
		slog.Int("accepted_count", finalResult.AcceptedCount),
		slog.Int("rejected_count", finalResult.RejectedCount),
		slog.Int("duplicate_count", finalResult.DuplicateCount),
		slog.String("audit_log_file", finalResult.AuditLogFile),
	)

	return finalResult, nil
}

func (s *ticketEventService) filterAndGroupEvents(parsedEvents []parsedEvent) ([]ticketWorkerJob, map[string][]model.TicketEvent, int, []uint, []string) {
	validEvents := make([]model.TicketEvent, 0, len(parsedEvents))
	rejectedEvents := make(map[string][]model.TicketEvent)
	rejectedCount := 0

	for _, pe := range parsedEvents {
		if pe.Err != nil {
			key := pe.Err.Error()
			rejectedEvents[key] = append(rejectedEvents[key], pe.Event)
			rejectedCount++
			continue
		}
		validEvents = append(validEvents, pe.Event)
	}

	groupedEvents := make(map[uint][]model.TicketEvent)
	var ticketIDs []uint
	var eventKeys []string

	for _, e := range validEvents {
		if _, ok := groupedEvents[e.TicketID]; !ok {
			ticketIDs = append(ticketIDs, e.TicketID)
		}
		groupedEvents[e.TicketID] = append(groupedEvents[e.TicketID], e)
		eventKeys = append(eventKeys, e.HashKey())
	}

	var workerJobs []ticketWorkerJob
	for id, group := range groupedEvents {
		sort.Slice(group, func(i, j int) bool {
			return group[i].CreatedAt.Before(group[j].CreatedAt)
		})
		workerJobs = append(workerJobs, ticketWorkerJob{TicketID: id, Events: group})
	}

	return workerJobs, rejectedEvents, rejectedCount, ticketIDs, eventKeys
}

func (s *ticketEventService) fetchMetadata(ctx context.Context, ticketIDs []uint, eventKeys []string) (importMetadata, error) {
	existingTickets, err := s.ticketRepo.GetExistingTicketIDs(ctx, ticketIDs)
	if err != nil {
		return importMetadata{}, fmt.Errorf("failed to fetch tickets: %w", err)
	}

	existingTicketStatuses, ticketCreatedAtByTicket, existingTicketAssignees, err := s.ticketRepo.GetTicketStatusAndCreatedAt(ctx, ticketIDs)
	if err != nil {
		return importMetadata{}, fmt.Errorf("failed to fetch ticket metadata: %w", err)
	}

	existingDBEvents, err := s.eventRepo.GetExistingEventKeys(ctx, eventKeys)
	if err != nil {
		return importMetadata{}, fmt.Errorf("failed to fetch existing events: %w", err)
	}

	return importMetadata{
		existingTickets:         existingTickets,
		existingTicketStatuses:  existingTicketStatuses,
		ticketCreatedAt:         ticketCreatedAtByTicket,
		existingDBEvents:        existingDBEvents,
		existingTicketAssignees: existingTicketAssignees,
	}, nil
}

func (s *ticketEventService) simulateTicketFSM(job ticketWorkerJob, meta importMetadata) ticketJobResult {
	var res ticketJobResult
	ticketID := job.TicketID

	if !meta.existingTickets[ticketID] {
		return rejectJob(job, fmt.Errorf("ticket_id does not exist in DB"))
	}

	currentStatus, ok := meta.existingTicketStatuses[ticketID]
	if !ok {
		return rejectJob(job, fmt.Errorf("ticket_id does not exist in DB"))
	}
	ticketCreatedAt := meta.ticketCreatedAt[ticketID]
	currentAssigneeID := meta.existingTicketAssignees[ticketID]

	localSeen := make(map[string]bool)
	var finalJob *updateJob

	ticket := &model.Ticket{
		ID:              ticketID,
		Status:          currentStatus,
		AssigneeID:      currentAssigneeID,
		TicketCreatedAt: ticketCreatedAt,
	}

	for _, event := range job.Events {
		key := event.HashKey()

		if meta.existingDBEvents[key] || localSeen[key] {
			res.DuplicateCount++
			continue
		}

		if event.FromStatus != ticket.Status {
			return rejectJob(job, errmsgs.ErrInvalidFlowTicket)
		}

		if event.ToStatus == model.StatusResolved || event.ToStatus == model.StatusCancelled {
			if event.CreatedAt.Before(ticketCreatedAt) {
				status := string(event.ToStatus)
				if len(status) > 0 {
					status = strings.ToUpper(status[:1]) + status[1:]
				}
				return rejectJob(job, fmt.Errorf("%s: %s At cannot be before Created At", errmsgs.ErrInvalidInput.Error(), status))
			}
		}

		reqAssigneeId := strings.TrimSpace(event.AssigneeID)
		if ticket.Status == model.StatusNew && event.ToStatus == model.StatusAssigned {
			if reqAssigneeId == "" {
				return rejectJob(job, fmt.Errorf("%w: Assignee ID is required when assigning a ticket", errmsgs.ErrInvalidInput))
			}
			ticket.AssigneeID = reqAssigneeId
		} else if reqAssigneeId != "" && reqAssigneeId != ticket.AssigneeID {
			return rejectJob(job, fmt.Errorf("%w: Cannot change assignee during status transition to '%s'", errmsgs.ErrInvalidInput, event.ToStatus))
		}

		localSeen[key] = true
		ticket.Status = event.ToStatus
		ticket.Status = event.ToStatus
		res.AcceptedEvents = append(res.AcceptedEvents, event)

		finalJob = &updateJob{
			TicketID:    ticketID,
			Status:      ticket.Status,
			AssigneeID:  ticket.AssigneeID,
			CreatedAt:   event.CreatedAt,
			ResolvedAt:  ticket.ResolvedAt,
			CancelledAt: ticket.CancelledAt,
		}
	}
	res.FinalUpdateJob = finalJob
	return res
}

func rejectJob(job ticketWorkerJob, err error) ticketJobResult {
	return ticketJobResult{
		RejectedError:  err.Error(),
		RejectedEvents: job.Events,
	}
}

func (s *ticketEventService) applyDBResults(ctx context.Context, eventsToInsert []model.TicketEvent, finalUpdates []updateJob) error {
	// Wrap DB operations inside a Database Transaction
	return s.ticketRepo.Transaction(ctx, func(txCtx context.Context) error {
		if len(eventsToInsert) > 0 {
			if err := s.eventRepo.CreateBatch(txCtx, eventsToInsert); err != nil {
				return err
			}
		}

		if len(finalUpdates) > 0 {
			var closedTicketIDs []int
			for _, u := range finalUpdates {
				if u.Status == model.StatusClosed && u.ResolvedAt == nil {
					closedTicketIDs = append(closedTicketIDs, int(u.TicketID))
				}
			}

			resolvedAtByTicket := make(map[uint]time.Time)
			if len(closedTicketIDs) > 0 {
				resolvedEvents, err := s.eventRepo.FetchLatestResolvedEventPerTicket(txCtx, closedTicketIDs)
				if err == nil {
					for _, ev := range resolvedEvents {
						resolvedAtByTicket[ev.TicketID] = ev.CreatedAt
					}
				}
			}

			tickets := make([]model.Ticket, len(finalUpdates))
			for i, u := range finalUpdates {
				var resolvedAt *time.Time = u.ResolvedAt
				if u.Status == model.StatusClosed && resolvedAt == nil {
					if rTime, ok := resolvedAtByTicket[u.TicketID]; ok {
						resolvedAt = &rTime
					}
				} else if u.Status == model.StatusResolved && resolvedAt == nil {
					t := u.CreatedAt
					resolvedAt = &t
				}

				var cancelledAt *time.Time = u.CancelledAt
				if u.Status == model.StatusCancelled && cancelledAt == nil {
					t := u.CreatedAt
					cancelledAt = &t
				}

				tickets[i] = model.Ticket{
					ID:          u.TicketID,
					Status:      u.Status,
					AssigneeID:  u.AssigneeID,
					ResolvedAt:  resolvedAt,
					CancelledAt: cancelledAt,
				}
			}

			if err := s.ticketRepo.UpdateStatusesBatch(txCtx, tickets); err != nil {
				return fmt.Errorf("failed to update ticket statuses in batch: %w", err)
			}
		}

		return nil
	})
}

func (s *ticketEventService) GetAuditLogPath(filename string) (string, error) {
	return s.auditLogger.GetAuditLogPath(filename)
}
