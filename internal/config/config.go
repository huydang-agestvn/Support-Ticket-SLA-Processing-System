package config

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type Config struct {
	DBHost         string
	DBPort         int
	DBUser         string
	DBPassword     string
	DBName         string
	DBSSLMode      string
	ServerPort     int
	WorkerPoolSize int
	DB             *gorm.DB

	// Keycloak config
	KeycloakBaseURL      string
	KeycloakRealm        string
	KeycloakClientID     string
	KeycloakClientSecret string
	KeycloakIssuer       string
	KeycloakTokenURL     string
	KeycloakJWKSURL      string

	// SMTP config
	SMTPHost     string
	SMTPPort     int
	SMTPUser     string
	SMTPPass     string
	ManagerEmail string

	// Audit Log Dir
	AuditLogDir string

	// MinIO Config
	MinioEndpoint   string
	MinioAccessKey  string
	MinioSecretKey  string
	MinioUseSSL     bool
	MinioBucketName string

	//AI Config
	AIProvider          string
	AIModel             string
	AIFallbackChain     string
	AIBaseURL           string
	AIAPIKey            string
	AIGroqBaseURL       string
	AIGroqAPIKey        string
	AIOpenRouterBaseURL string
	AIOpenRouterAPIKey  string
	AIGeminiBaseURL     string
	AIGeminiAPIKey      string
	AITimeoutSecs       int
	AIMaxRetries        int
	AIEnabled           bool
	AIPromptVersion     string
	AIMaxBatchSize      int
	AIWorkerPoolSize    int

	// Embedding Microservice
	EmbeddingServiceURL   string
	EmbeddingModel        string
	AIRagThreshold        float64
	AIRagContextThreshold float64

	// Ticket safety ML scorer
	TicketSafetyMLURL     string
	TicketSafetyMLTimeout int
}

func init() {
	_ = loadEnv()
}

// LoadConfig
func LoadConfig() *Config {
	err := loadEnv()
	if err != nil {
		slog.WarnContext(context.Background(), "No .env file found, using system environment variables", slog.Any("error", err))
	}

	minioUseSSL, _ := strconv.ParseBool(getEnv("MINIO_USE_SSL"))
	minioBucket := getEnv("MINIO_BUCKET_NAME")
	if minioBucket == "" {
		minioBucket = "audit-logs"
	}

	aiEnabled, _ := strconv.ParseBool(getEnv("AI_ENABLED"))

	aiTimeoutSecs := getEnvInt("AI_TIMEOUT_SECS")
	if aiTimeoutSecs == 0 {
		aiTimeoutSecs = 30
	}

	aiMaxRetries := getEnvInt("AI_MAX_RETRIES")
	if aiMaxRetries == 0 {
		aiMaxRetries = 2
	}

	aiPromptVersion := getEnv("AI_PROMPT_VERSION")
	if aiPromptVersion == "" {
		aiPromptVersion = "v1.0"
	}

	aiMaxBatchSize := getEnvInt("AI_MAX_BATCH_SIZE")
	if aiMaxBatchSize == 0 {
		aiMaxBatchSize = 30
	}

	aiWorkerPoolSize := getEnvInt("AI_WORKER_POOL_SIZE")
	if aiWorkerPoolSize == 0 {
		aiWorkerPoolSize = 3
	}

	aiRagThresholdStr := getEnv("AI_RAG_THRESHOLD")
	aiRagThreshold, err := strconv.ParseFloat(aiRagThresholdStr, 64)
	if err != nil || aiRagThreshold == 0.0 {
		aiRagThreshold = 0.9
	}

	aiRagContextThresholdStr := getEnv("AI_RAG_CONTEXT_THRESHOLD")
	aiRagContextThreshold, err := strconv.ParseFloat(aiRagContextThresholdStr, 64)
	if err != nil || aiRagContextThreshold == 0.0 {
		aiRagContextThreshold = 0.4
	}

	ticketSafetyMLTimeout := getEnvIntWithFallback("TICKET_SAFETY_ML_TIMEOUT_SECS", "ML_SIDECAR_TIMEOUT_SECS")
	if ticketSafetyMLTimeout == 0 {
		ticketSafetyMLTimeout = 3
	}

	cfg := &Config{
		// Database: Found environment variables for database configuration
		DBHost:     getEnv("DB_HOST"),
		DBPort:     getEnvInt("DB_PORT"),
		DBUser:     getEnv("DB_USER"),
		DBPassword: getEnv("DB_PASSWORD"),
		DBName:     getEnv("DB_NAME"),
		DBSSLMode:  getEnv("DB_SSLMODE"),

		ServerPort:     getEnvInt("SERVER_PORT"),
		WorkerPoolSize: getEnvInt("WORKER_POOL_SIZE"),

		KeycloakBaseURL:      getEnv("KEYCLOAK_BASE_URL"),
		KeycloakRealm:        getEnv("KEYCLOAK_REALM"),
		KeycloakClientID:     getEnv("KEYCLOAK_CLIENT_ID"),
		KeycloakClientSecret: getEnv("KEYCLOAK_CLIENT_SECRET"),
		KeycloakIssuer:       getEnv("KEYCLOAK_ISSUER"),
		KeycloakTokenURL:     getEnv("KEYCLOAK_TOKEN_URL"),
		KeycloakJWKSURL:      getEnv("KEYCLOAK_JWKS_URL"),

		SMTPHost:     getEnv("SMTP_HOST"),
		SMTPPort:     getEnvInt("SMTP_PORT"),
		SMTPUser:     getEnv("SMTP_USER"),
		SMTPPass:     getEnv("SMTP_PASS"),
		ManagerEmail: getEnv("MANAGER_EMAIL"),

		MinioEndpoint:   getEnv("MINIO_ENDPOINT"),
		MinioAccessKey:  getEnv("MINIO_ACCESS_KEY"),
		MinioSecretKey:  getEnv("MINIO_SECRET_KEY"),
		MinioUseSSL:     minioUseSSL,
		MinioBucketName: minioBucket,

		AIProvider:          getEnv("AI_PROVIDER"),
		AIModel:             getEnv("AI_MODEL"),
		AIFallbackChain:     getEnv("AI_FALLBACK_CHAIN"),
		AIBaseURL:           getEnv("AI_BASE_URL"),
		AIGroqBaseURL:       getEnv("AI_GROQ_BASE_URL"),
		AIGroqAPIKey:        getEnv("AI_GROQ_API_KEY"),
		AIOpenRouterBaseURL: getEnv("AI_OPENROUTER_BASE_URL"),
		AIOpenRouterAPIKey:  getEnv("AI_OPENROUTER_API_KEY"),
		AIGeminiBaseURL:     getEnv("AI_GEMINI_BASE_URL"),
		AIGeminiAPIKey:      getEnv("AI_GEMINI_API_KEY"),
		AITimeoutSecs:       aiTimeoutSecs,
		AIMaxRetries:        aiMaxRetries,
		AIEnabled:           aiEnabled,
		AIPromptVersion:     aiPromptVersion,
		AIMaxBatchSize:      aiMaxBatchSize,
		AIWorkerPoolSize:    aiWorkerPoolSize,

		EmbeddingServiceURL:   getEmbeddingServiceURL(),
		EmbeddingModel:        getEmbeddingModel(),
		AIRagThreshold:        aiRagThreshold,
		AIRagContextThreshold: aiRagContextThreshold,

		TicketSafetyMLURL:     getTicketSafetyMLURL(),
		TicketSafetyMLTimeout: ticketSafetyMLTimeout,
	}

	return cfg
}

func (c *Config) GetDSN() string {
	return fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		c.DBHost, c.DBPort, c.DBUser, c.DBPassword, c.DBName, c.DBSSLMode,
	)
}

func (c *Config) GetDatabase() (*gorm.DB, error) {
	if c.DB != nil {
		return c.DB, nil
	}

	var db *gorm.DB
	var err error
	maxRetries := 5
	retryDelay := time.Second

	for i := 0; i < maxRetries; i++ {
		db, err = gorm.Open(postgres.Open(c.GetDSN()), &gorm.Config{})
		if err == nil {
			c.DB = db
			return db, nil
		}

		if i < maxRetries-1 {
			fmt.Printf("Failed to connect to database (attempt %d/%d), retrying in %s...\n", i+1, maxRetries, retryDelay)
			time.Sleep(retryDelay)
			retryDelay *= 2
		}
	}
	return nil, fmt.Errorf("failed to connect to database after %d retries: %w", maxRetries, err)
}

func getEnv(key string) string {
	value := os.Getenv(key)
	return value
}

func GetPoolSize(key string) int {
	value := getEnv(key)
	intVal, err := strconv.Atoi(value)
	if err != nil {
		slog.WarnContext(context.Background(), "Error converting %s to integer: %v. Using default value 5", key, err)
		return 5
	}
	return intVal
}
func GetBatchSize(key string) int {
	value := getEnv(key)
	intVal, err := strconv.Atoi(value)
	if err != nil {
		slog.WarnContext(context.Background(), "Error converting %s to integer: %v. Using default value 1000", key, err)
		return 1000
	}
	return intVal
}

func getEnvInt(key string) int {
	value := getEnv(key)
	intVal, err := strconv.Atoi(value)
	if err != nil {
		slog.ErrorContext(context.Background(), "Error converting %s to integer: %v", key, err)
	}
	return intVal
}

func getEnvIntWithFallback(primaryKey, fallbackKey string) int {
	if value := getEnv(primaryKey); value != "" {
		intVal, err := strconv.Atoi(value)
		if err != nil {
			slog.ErrorContext(context.Background(), "Error converting %s to integer: %v", primaryKey, err)
		}
		return intVal
	}
	return getEnvInt(fallbackKey)
}

func loadEnv() error {
	paths := []string{".env", "../.env", "../../.env", "../../../.env"}
	for _, p := range paths {
		if err := godotenv.Load(p); err == nil {
			return nil
		}
	}
	return fmt.Errorf("no .env file found")
}

func getEmbeddingServiceURL() string {
	url := getEnv("EMBEDDING_SERVICE_URL")
	if url == "" {
		return "http://localhost:11434"
	}
	return url
}

// getEmbeddingModel returns the Ollama embedding model to use.
func getEmbeddingModel() string {
	model := getEnv("EMBEDDING_MODEL")
	if model == "" {
		return "nomic-embed-text"
	}
	return model
}

func getTicketSafetyMLURL() string {
	url := getEnv("TICKET_SAFETY_ML_URL")
	if url == "" {
		url = getEnv("ML_SIDECAR_URL")
	}
	if url == "" {
		return "http://ticket-safety-ml:8000/score"
	}
	return url
}
