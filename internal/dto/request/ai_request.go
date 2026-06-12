package request

type GroqRequest struct {
	Model          string         `json:"model"`
	Messages       []GroqMessage  `json:"messages"`
	Temperature    float64        `json:"temperature"`
	ResponseFormat ResponseFormat `json:"response_format"`
}

type GroqMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ResponseFormat struct {
	Type       string      `json:"type"`
	JSONSchema *JSONSchema `json:"json_schema,omitempty"`
}

type JSONSchema struct {
	Name   string         `json:"name"`
	Strict bool           `json:"strict"`
	Schema map[string]any `json:"schema"`
}
