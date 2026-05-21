package request

type LoginRequest struct {
	Username string `json:"username" form:"username" binding:"required" example:"admin"`
	Password string `json:"password" form:"password" binding:"required" example:"admin123"`
}
