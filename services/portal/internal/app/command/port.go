// Package command is the write-side application layer for the portal
// service. Handlers in this package translate inbound commands into
// domain mutations and persist them through the [UnitOfWork] port
// declared here. CQRS purity is enforced at the package boundary: no
// query types live here, and handlers depend on per-aggregate Writer
// ports rather than full repository interfaces.
//
// The postgres-backed implementation of [UnitOfWork] lives in
// internal/infra/postgres/uow.
package command

import (
	"bootstrap/services/portal/internal/domain/organization"
	"bootstrap/services/portal/internal/domain/staff"
	"context"
)

// TransactionalUnitOfWork is the accessor surface a command handler
// sees inside an open transaction. Each method returns a per-aggregate
// Writer bound to the current transaction; mutations made through
// these writers commit or roll back as one unit.
//
// The transaction is always tenant-scoped: it is opened by
// [UnitOfWork.DoOrganizationTransaction], which binds the organization
// to the connection (Row-Level Security) before the handler runs. Every
// writer reached through this surface is therefore constrained to that
// one organization's rows.
type TransactionalUnitOfWork interface {
	Organizations() organization.Writer
	Staffs() staff.Writer
}

// TransactionalUnitOfWorkHandler is the closure a command handler passes
// to [UnitOfWork.DoOrganizationTransaction]. It runs inside the open,
// tenant-scoped transaction and reaches every Writer through utx; the
// whole closure commits or rolls back as one unit.
type TransactionalUnitOfWorkHandler func(ctx context.Context, utx TransactionalUnitOfWork) error

// UnitOfWork is the write-side persistence port command handlers depend
// on. It exposes a single, tenant-scoped entry point:
//
//   - DoOrganizationTransaction(ctx, id, handler) opens a transaction,
//     validates id, binds the organization to the connection via
//     Row-Level Security (set_config('app.organization_id', …, true)),
//     and hands the caller a [TransactionalUnitOfWork] bound to that
//     transaction. Every writer resolved through it is automatically
//     filtered to the bound organization; the closure commits or rolls
//     back as one unit.
//
// There is intentionally no org-less / auto-commit write path: in a
// multi-tenant system every write MUST be scoped to an organization so
// RLS can enforce isolation. The id is validated as a UUIDv7
// (see idgen.Validate) before any statement runs; an invalid or empty
// id aborts the transaction.
type UnitOfWork interface {
	DoOrganizationTransaction(ctx context.Context, id organization.ID, handler TransactionalUnitOfWorkHandler) error
}
