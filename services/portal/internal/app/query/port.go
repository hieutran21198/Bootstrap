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
	"context"
)

// TransactionalReadStore is the accessor surface a query handler sees
// inside an open, tenant-scoped read transaction. Each method returns a
// per-aggregate Reader bound to the current transaction; every read
// through it is filtered to the bound organization by Row-Level
// Security.
type TransactionalReadStore interface {
	Organizations() organization.Reader
	Staffs() staff.Reader
}

// TransactionalReadStoreHandler is the closure a query handler passes to
// [ReadStore.DoOrganizationQuery]. It runs inside the open, RLS-bound
// read transaction and reaches every Reader through rs.
type TransactionalReadStoreHandler func(ctx context.Context, rs TransactionalReadStore) error

// ReadStore is the read-side persistence port query handlers depend on.
// It exposes a single, tenant-scoped entry point:
//
//   - DoOrganizationQuery(ctx, id, handler) opens a transaction,
//     validates id, binds the organization to the connection via
//     Row-Level Security (set_config('app.organization_id', …, true)),
//     and hands the caller a [TransactionalReadStore] bound to that
//     transaction. Every reader resolved through it is automatically
//     filtered to the bound organization.
//
// There is intentionally no org-less read path: in a multi-tenant
// system every read MUST be scoped to an organization so RLS can
// enforce isolation — an unbound read fails closed (zero rows) against
// a FORCEd policy. The id is validated as a UUIDv7 (see idgen.Validate)
// before any statement runs.
//
// Complex read models — joins, projections, list views — belong in
// consumer-defined interfaces returning DTOs, not on this port; they
// run inside the same DoOrganizationQuery transaction.
type ReadStore interface {
	DoOrganizationQuery(ctx context.Context, id organization.ID, handler TransactionalReadStoreHandler) error
}
