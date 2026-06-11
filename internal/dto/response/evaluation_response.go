package response

import (
	"encoding/json"
	"time"
)

type AIEvaluationResponse struct {
	RunID         uint                `json:"run_id"`
	RunDate       time.Time           `json:"run_date"`
	PromptVersion string              `json:"prompt_version"`
	Metrics       AIEvaluationMetrics `json:"metrics"`
	DetailRaw     json.RawMessage     `json:"detail_raw"`
}

type AIEvaluationMetrics struct {
	Accuracy      AccuracyMetrics      `json:"accuracy"`
	Performance   PerformanceMetrics   `json:"performance"`
	ResourceUsage ResourceUsageMetrics `json:"resource_usage"`
}

type AccuracyMetrics struct {
	TotalCases   int     `json:"total_cases"`
	PassedCases  int     `json:"passed_cases"`
	FailedCases  int     `json:"failed_cases"`
	AccuracyRate float64 `json:"accuracy_rate"`
}

type PerformanceMetrics struct {
	TotalDurationMs int64   `json:"total_duration_ms"`
	AvgLatencyMs    int64   `json:"avg_latency_ms"`
	ThroughputCPS   float64 `json:"throughput_cps"`
}

type ResourceUsageMetrics struct {
	TotalPromptTokens     int     `json:"total_prompt_tokens"`
	TotalCompletionTokens int     `json:"total_completion_tokens"`
	TotalTokens           int     `json:"total_tokens"`
	EstimatedCostUSD      float64 `json:"estimated_cost_usd"`
}
