// Package echox wraps echo v4 with recommended middleware and HTTP
// server timeouts. Single-responsibility per packages/go/AGENTS.md:
// one Config, one target (Echox), one constructor (New).
package echox

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

// Config controls listener, timeouts, and middleware behavior. Zero values
// receive sane defaults inside New; the value passed in is treated as
// frozen post-construction.
type Config struct {
	Addr              string        // listen address; default ":8080"
	ReadTimeout       time.Duration // default 5s
	ReadHeaderTimeout time.Duration // default 3s
	WriteTimeout      time.Duration // default 10s
	IdleTimeout       time.Duration // default 60s
	ShutdownTimeout   time.Duration // graceful-shutdown deadline; default 10s
	MaxHeaderBytes    int           // default 1 MiB
	BodyLimit         string        // echo BodyLimit format, default "2M"
	GzipLevel         int           // 1..9; default 5
	CORSOrigins       []string      // nil/empty disables CORS; non-empty enables it with those origins
}

// Echox is the configured echo server.
type Echox struct {
	cfg    Config
	echo   *echo.Echo
	server *http.Server
}

// New builds an echo server with Recover → RequestID → RequestLogger →
// Secure → Gzip → BodyLimit → CORS (if configured), and applies HTTP timeouts.
// The RequestLogger middleware writes structured records to slog.Default();
// override via slog.SetDefault before constructing the server.
func New(cfg Config) *Echox {
	cfg = applyDefaults(cfg)

	e := echo.New()
	e.HideBanner = true
	e.HidePort = true

	e.Use(middleware.Recover())
	e.Use(middleware.RequestID())
	e.Use(middleware.RequestLoggerWithConfig(middleware.RequestLoggerConfig{
		LogStatus:    true,
		LogURI:       true,
		LogMethod:    true,
		LogLatency:   true,
		LogRequestID: true,
		LogError:     true,
		HandleError:  true,
		LogValuesFunc: func(c echo.Context, v middleware.RequestLoggerValues) error {
			level := slog.LevelInfo
			if v.Error != nil || v.Status >= 500 {
				level = slog.LevelError
			} else if v.Status >= 400 {
				level = slog.LevelWarn
			}
			attrs := []slog.Attr{
				slog.String("method", v.Method),
				slog.String("uri", v.URI),
				slog.Int("status", v.Status),
				slog.Duration("latency", v.Latency),
				slog.String("request_id", v.RequestID),
			}
			if v.Error != nil {
				attrs = append(attrs, slog.String("error", v.Error.Error()))
			}
			slog.LogAttrs(c.Request().Context(), level, "http.request", attrs...)
			return nil
		},
	}))
	e.Use(middleware.Secure())
	e.Use(middleware.GzipWithConfig(middleware.GzipConfig{Level: cfg.GzipLevel}))
	e.Use(middleware.BodyLimit(cfg.BodyLimit))
	if len(cfg.CORSOrigins) > 0 {
		e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
			AllowOrigins: cfg.CORSOrigins,
		}))
	}

	srv := &http.Server{
		Addr:              cfg.Addr,
		ReadTimeout:       cfg.ReadTimeout,
		ReadHeaderTimeout: cfg.ReadHeaderTimeout,
		WriteTimeout:      cfg.WriteTimeout,
		IdleTimeout:       cfg.IdleTimeout,
		MaxHeaderBytes:    cfg.MaxHeaderBytes,
	}

	return &Echox{cfg: cfg, echo: e, server: srv}
}

// Echo exposes the underlying *echo.Echo for route registration.
func (x *Echox) Echo() *echo.Echo { return x.echo }

// Start serves HTTP and blocks. When ctx is canceled it performs a graceful
// shutdown bounded by Config.ShutdownTimeout. Returns nil on graceful close.
func (x *Echox) Start(ctx context.Context) error {
	errCh := make(chan error, 1)
	go func() { errCh <- x.echo.StartServer(x.server) }()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), x.cfg.ShutdownTimeout)
		defer cancel()
		return x.Shutdown(shutdownCtx)
	case err := <-errCh:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}

// Shutdown gracefully stops the server.
func (x *Echox) Shutdown(ctx context.Context) error {
	return x.echo.Shutdown(ctx)
}

func applyDefaults(cfg Config) Config {
	if cfg.Addr == "" {
		cfg.Addr = ":8080"
	}
	if cfg.ReadTimeout == 0 {
		cfg.ReadTimeout = 5 * time.Second
	}
	if cfg.ReadHeaderTimeout == 0 {
		cfg.ReadHeaderTimeout = 3 * time.Second
	}
	if cfg.WriteTimeout == 0 {
		cfg.WriteTimeout = 10 * time.Second
	}
	if cfg.IdleTimeout == 0 {
		cfg.IdleTimeout = 60 * time.Second
	}
	if cfg.ShutdownTimeout == 0 {
		cfg.ShutdownTimeout = 10 * time.Second
	}
	if cfg.MaxHeaderBytes == 0 {
		cfg.MaxHeaderBytes = 1 << 20
	}
	if cfg.BodyLimit == "" {
		cfg.BodyLimit = "2M"
	}
	if cfg.GzipLevel == 0 {
		cfg.GzipLevel = 5
	}
	return cfg
}
