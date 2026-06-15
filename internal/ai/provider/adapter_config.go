package provider

type Config struct {
	ProviderName  string
	BaseURL       string
	APIKey        string
	Model         string
	TimeoutSecs   int
	MaxRetries    int
	PromptVersion string
	Headers       map[string]string
}
