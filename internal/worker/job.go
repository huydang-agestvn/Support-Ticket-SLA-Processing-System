package worker

import (
	"sync"

	"support-ticket.com/internal/config"
)

type JobResult[R any] struct {
	Value R
	Err   error
}

var worker = config.GetPoolSize("WORKER_POOL_SIZE")

func Run[T any, R any](items []T, job func(T) R) []R {
	return RunWithPoolSize(items, worker, job)
}

func RunWithPoolSize[T any, R any](items []T, poolSize int, job func(T) R) []R {
	if poolSize <= 0 {
		poolSize = 1
	}
	jobs := make(chan T, len(items))
	results := make(chan R, len(items))
	var wg sync.WaitGroup

	for i := 0; i < poolSize; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for item := range jobs {
				results <- job(item)
			}
		}()
	}

	for _, item := range items {
		jobs <- item
	}
	close(jobs)

	go func() {
		wg.Wait()
		close(results)
	}()

	var allResults []R
	for r := range results {
		allResults = append(allResults, r)
	}
	return allResults
}
