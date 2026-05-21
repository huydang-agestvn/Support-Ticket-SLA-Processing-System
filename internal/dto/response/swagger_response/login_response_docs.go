package swagger_response

type LoginDataDoc struct {
	AccessToken      string `json:"access_token" example:"eyJhbGciOiJSUzI1NiIsInR5cCI..."`
	TokenType        string `json:"token_type" example:"Bearer"`
	ExpiresIn        int    `json:"expires_in" example:"300"`
	RefreshExpiresIn int    `json:"refresh_expires_in" example:"1800"`
	Scope            string `json:"scope" example:"profile email"`
}

type LoginSuccessResponseDoc struct {
	Success bool         `json:"success" example:"true"`
	Data    LoginDataDoc `json:"data"`
}
