package response

type LoginResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	ExpiresIn   int    `json:"expires_in"`
	//RefreshToken     string `json:"refresh_token"`
	//RefreshExpiresIn int    `json:"refresh_expires_in"`
	//Scope string `json:"scope"`
}
