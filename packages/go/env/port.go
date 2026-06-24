package env

import "context"

// Loader loads a set of key/value pairs from some source.
type Loader interface {
	Load(ctx context.Context) (map[string]string, error)
}
