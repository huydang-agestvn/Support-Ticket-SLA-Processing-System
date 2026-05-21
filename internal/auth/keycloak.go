package auth

import (
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"support-ticket.com/internal/dto/common"
)

type KeycloakAuthenticator struct {
	Issuer   string
	ClientID string
	JWKSURL  string
}

type jwksResponse struct {
	Keys []jwkKey `json:"keys"`
}

type jwkKey struct {
	Kid string `json:"kid"`
	Kty string `json:"kty"`
	Use string `json:"use"`
	Alg string `json:"alg"`
	N   string `json:"n"`
	E   string `json:"e"`
}

func NewKeycloakAuthenticator(issuer, clientID, jwksURL string) *KeycloakAuthenticator {
	return &KeycloakAuthenticator{
		Issuer:   issuer,
		ClientID: clientID,
		JWKSURL:  jwksURL,
	}
}

// VerifyToken validates the JWT and returns the user principal.
// All token-level failures are returned as 401 Unauthorized so that
// HandleError correctly classifies them without falling back to 500.
func (a *KeycloakAuthenticator) VerifyToken(tokenString string) (UserPrincipal, error) {
	tokenString = strings.TrimSpace(tokenString)
	if tokenString == "" {
		return UserPrincipal{}, common.NewUnauthorized(common.ErrCodeUnauthorized, "token is required")
	}

	claims := &KeycloakClaims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (any, error) {
		if token.Method.Alg() != jwt.SigningMethodRS256.Alg() {
			return nil, fmt.Errorf("unexpected signing method: %s", token.Method.Alg())
		}

		kid, ok := token.Header["kid"].(string)
		if !ok || kid == "" {
			return nil, fmt.Errorf("missing kid in token header")
		}

		return a.getPublicKey(kid)
	})

	if err != nil {
		return UserPrincipal{}, common.NewUnauthorized(common.ErrCodeUnauthorized, "invalid or expired token")
	}

	if !token.Valid {
		return UserPrincipal{}, common.NewUnauthorized(common.ErrCodeUnauthorized, "invalid token")
	}

	if claims.Issuer != a.Issuer {
		return UserPrincipal{}, common.NewUnauthorized(common.ErrCodeUnauthorized, "token issuer is not trusted")
	}

	if claims.AuthorizedParty != a.ClientID {
		return UserPrincipal{}, common.NewUnauthorized(common.ErrCodeUnauthorized, "token was not issued for this client")
	}

	principal := claims.ToPrincipal()
	if principal.UserID == "" {
		return UserPrincipal{}, common.NewUnauthorized(common.ErrCodeUnauthorized, "token is missing user identity")
	}

	if !principal.HasBusinessRole() {
		return UserPrincipal{}, common.NewForbidden(common.ErrCodeForbidden, "user has no valid business role")
	}

	return principal, nil
}

func (a *KeycloakAuthenticator) getPublicKey(kid string) (*rsa.PublicKey, error) {
	resp, err := http.Get(a.JWKSURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch JWKS: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch JWKS, status: %d", resp.StatusCode)
	}

	var jwks jwksResponse
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return nil, fmt.Errorf("failed to decode JWKS: %w", err)
	}

	for _, key := range jwks.Keys {
		if key.Kid == kid {
			return buildRSAPublicKey(key)
		}
	}

	return nil, fmt.Errorf("public key not found for kid: %s", kid)
}

func buildRSAPublicKey(key jwkKey) (*rsa.PublicKey, error) {
	nBytes, err := base64.RawURLEncoding.DecodeString(key.N)
	if err != nil {
		return nil, fmt.Errorf("failed to decode modulus: %w", err)
	}

	eBytes, err := base64.RawURLEncoding.DecodeString(key.E)
	if err != nil {
		return nil, fmt.Errorf("failed to decode exponent: %w", err)
	}

	n := new(big.Int).SetBytes(nBytes)

	e := 0
	for _, b := range eBytes {
		e = e<<8 + int(b)
	}

	return &rsa.PublicKey{
		N: n,
		E: e,
	}, nil
}
