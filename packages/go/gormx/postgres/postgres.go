// Package postgres provides a gorm postgres dialector via
// gorm.io/driver/postgres (jackc/pgx under the hood, pure Go). Pair the
// returned Dialector with gormx.New. Single-responsibility per
// packages/go/AGENTS.md.
package postgres

import (
	"net"
	"net/url"
	"strconv"
	"time"

	gormpostgres "gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// Config holds the strongly-typed connection parameters and the
// postgres-driver knobs exposed at this layer. The package renders a
// `postgres://...` URL from these fields internally via net/url; callers
// never hand-craft a DSN string.
//
// Empty fields are omitted from the URL so libpq's own defaults apply
// (host = unix socket, port = 5432, etc.). SSLMode defaults to "disable"
// because development is the common case; override explicitly in
// production (e.g. "require", "verify-full").
type Config struct {
	Host            string        // empty → libpq default; otherwise TCP hostname or IP
	Port            int           // 0 → libpq default (5432)
	User            string        // required
	Password        string        // optional
	Database        string        // required
	SSLMode         string        // empty → "disable"
	ApplicationName string        // optional; surfaces in pg_stat_activity
	ConnectTimeout  time.Duration // 0 → no timeout; sub-second values are bumped to 1s

	// PreferSimpleProtocol disables prepared statements. Required when
	// running behind connection poolers that operate at transaction or
	// statement level (e.g. PgBouncer in transaction mode).
	PreferSimpleProtocol bool
}

// Postgres holds the constructed gorm.Dialector.
type Postgres struct {
	cfg       Config
	dialector gorm.Dialector
}

// New constructs the dialector. No I/O occurs here; the connection is
// established later when the dialector is passed to gormx.New.
func New(cfg Config) *Postgres {
	return &Postgres{
		cfg: cfg,
		dialector: gormpostgres.New(gormpostgres.Config{
			DSN:                  buildDSN(cfg),
			PreferSimpleProtocol: cfg.PreferSimpleProtocol,
		}),
	}
}

// Dialector returns the gorm.Dialector to feed into gormx.Config.
func (p *Postgres) Dialector() gorm.Dialector { return p.dialector }

// buildDSN renders a `postgres://` URL from Config using net/url. The
// stdlib handles percent-encoding of userinfo, query values, and the
// host:port pair (including IPv6 bracketing via net.JoinHostPort).
func buildDSN(cfg Config) string {
	u := url.URL{Scheme: "postgres"}

	if cfg.User != "" {
		if cfg.Password != "" {
			u.User = url.UserPassword(cfg.User, cfg.Password)
		} else {
			u.User = url.User(cfg.User)
		}
	}

	host := cfg.Host
	if host == "" && cfg.Port > 0 {
		host = "localhost"
	}
	if host != "" {
		if cfg.Port > 0 {
			u.Host = net.JoinHostPort(host, strconv.Itoa(cfg.Port))
		} else {
			u.Host = host
		}
	}

	if cfg.Database != "" {
		u.Path = "/" + cfg.Database
	}

	q := url.Values{}
	sslMode := cfg.SSLMode
	if sslMode == "" {
		sslMode = "disable"
	}
	q.Set("sslmode", sslMode)
	if cfg.ApplicationName != "" {
		q.Set("application_name", cfg.ApplicationName)
	}
	if cfg.ConnectTimeout > 0 {
		seconds := max(int(cfg.ConnectTimeout.Seconds()), 1)
		q.Set("connect_timeout", strconv.Itoa(seconds))
	}
	u.RawQuery = q.Encode()

	return u.String()
}
