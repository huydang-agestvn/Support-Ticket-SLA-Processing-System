package response

type LoginResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token,omitempty"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`

	//RefreshExpiresIn int    `json:"refresh_expires_in"`
	//Scope string `json:"scope"`
}
