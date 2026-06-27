// Package query is the read-side application layer for the portal
// service. Handlers in this package translate inbound queries into
// reads through the [ReadStore] port declared here. CQRS purity is
// enforced at the package boundary: no command types live here, and
// handlers depend on per-aggregate Reader ports rather than full
// repository interfaces.
//
// The postgres-backed implementation of [ReadStore] lives in
// internal/infra/postgres/readstore.
package query

import (
	"bootstrap/services/portal/internal/domain/organization"
	"bootstrap/services/portal/internal/domain/staff"
)

// ReadStore is the read-side persistence port query handlers depend on.
// Each method returns a per-aggregate Reader for simple aggregate
// loads (e.g. rs.Organizations().ByID(ctx, id)).
//
// Unlike [command.UnitOfWork] there is no transactional variant: reads
// do not need atomic multi-aggregate boundaries, so a single accessor
// surface is sufficient. Complex read models — joins, projections,
// list views — belong in consumer-defined interfaces returning DTOs,
// not on this port.
type ReadStore interface {
	Organizations() organization.Reader
	Staffs() staff.Reader
}
