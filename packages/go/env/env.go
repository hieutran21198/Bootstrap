// Package env provides composable environment-variable loaders and a typed
// parser backed by caarlos0/env v11.
package env

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"strings"

	caarlosenv "github.com/caarlos0/env/v11"
	"github.com/joho/godotenv"
)

// loaderFunc adapts a plain function to the Loader interface.
type loaderFunc func(ctx context.Context) (map[string]string, error)

func (f loaderFunc) Load(ctx context.Context) (map[string]string, error) {
	return f(ctx)
}

// FileLoader returns a Loader that reads .env files at the given paths via
// godotenv. A missing file (any path not found) is silently treated as an
// empty source — no error is returned. Any other I/O error is wrapped and
// propagated.
func FileLoader(paths ...string) Loader {
	return loaderFunc(func(_ context.Context) (map[string]string, error) {
		m, err := godotenv.Read(paths...)
		if err != nil {
			if errors.Is(err, fs.ErrNotExist) {
				return map[string]string{}, nil
			}
			return nil, fmt.Errorf("env: FileLoader: %w", err)
		}
		return m, nil
	})
}

// OSLoader returns a Loader that reads the current process's environment
// variables via os.Environ.
func OSLoader() Loader {
	return loaderFunc(func(_ context.Context) (map[string]string, error) {
		raw := os.Environ()
		m := make(map[string]string, len(raw))
		for _, pair := range raw {
			k, v, _ := strings.Cut(pair, "=")
			m[k] = v
		}
		return m, nil
	})
}

// Parse merges the key/value maps produced by each loader in order — later
// loaders override earlier ones — and then parses the merged map into dst
// using caarlos0/env v11. Any loader error or parse error is returned wrapped.
func Parse[T any](ctx context.Context, dst *T, loaders ...Loader) error {
	merged := make(map[string]string)
	for _, l := range loaders {
		m, err := l.Load(ctx)
		if err != nil {
			return fmt.Errorf("env: Parse: loader failed: %w", err)
		}
		for k, v := range m {
			merged[k] = v
		}
	}
	if err := caarlosenv.ParseWithOptions(dst, caarlosenv.Options{
		Environment: merged,
	}); err != nil {
		return fmt.Errorf("env: Parse: %w", err)
	}
	return nil
}
