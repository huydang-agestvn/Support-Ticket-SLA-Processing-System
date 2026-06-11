package request

type AIEvaluationRequest struct {
	PromptVersion     string `json:"prompt_version" binding:"required"`
	EvaluationCaseIDs []uint `json:"evaluation_case_ids"`
}
