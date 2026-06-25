package ai

import (
	"fmt"
	"strings"
)

// NormalizeTicketForEmbedding chuẩn hóa Ticket thành văn bản sạch sẽ để đưa vào Vector DB
func NormalizeTicketForEmbedding(title, description string) string {
	// 1. Loại bỏ các khoảng trắng thừa, ký tự xuống dòng liên tiếp
	cleanTitle := cleanText(title)
	cleanDesc := cleanText(description)

	// 2. Định dạng lại có Semantic Meaning (Ngữ nghĩa rõ ràng)
	normalizedText := fmt.Sprintf("Title: %s\nDescription: %s", cleanTitle, cleanDesc)

	return normalizedText
}

// cleanText loại bỏ khoảng trắng dư thừa
func cleanText(input string) string {
	// Loại bỏ khoảng trắng ở 2 đầu
	text := strings.TrimSpace(input)

	// Thay thế các khoảng trắng liên tiếp hoặc tab/newline thành 1 dấu cách duy nhất
	f := strings.Fields(text)
	return strings.Join(f, " ")
}
