package model

import (
	"database/sql/driver"
	"fmt"
	"strconv"
	"strings"
)

// Vector represents a multidimensional float32 vector in PostgreSQL (pgvector)
type Vector []float32

// Value implements the driver.Valuer interface to convert Vector to string representation for PostgreSQL
func (v Vector) Value() (driver.Value, error) {
	if len(v) == 0 {
		return nil, nil
	}
	var str strings.Builder
	str.WriteByte('[')
	for i, f := range v {
		if i > 0 {
			str.WriteByte(',')
		}
		str.WriteString(strconv.FormatFloat(float64(f), 'f', -1, 32))
	}
	str.WriteByte(']')
	return str.String(), nil
}

// Scan implements the sql.Scanner interface to parse PostgreSQL vector string representation back to Vector
func (v *Vector) Scan(src interface{}) error {
	if src == nil {
		*v = nil
		return nil
	}
	var s string
	switch val := src.(type) {
	case string:
		s = val
	case []byte:
		s = string(val)
	default:
		return fmt.Errorf("unsupported type for Vector scan: %T", src)
	}

	s = strings.Trim(s, "[]")
	if s == "" {
		*v = []float32{}
		return nil
	}
	parts := strings.Split(s, ",")
	res := make([]float32, len(parts))
	for i, p := range parts {
		f, err := strconv.ParseFloat(strings.TrimSpace(p), 32)
		if err != nil {
			return err
		}
		res[i] = float32(f)
	}
	*v = res
	return nil
}
