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

// UnitOfWork is the write-side persistence port command handlers
// depend on. It composes [TransactionalUnitOfWork] (the accessor
// surface) with DoTransaction (the transaction starter), so a single
// dependency exposes both modes to a handler:
//
//   - Single-aggregate writes use the embedded [TransactionalUnitOfWork]
//     accessors directly (e.g. uow.Organizations().Save(ctx, o)); the
//     implementation runs them in auto-commit mode.
//   - Atomic multi-aggregate writes call DoTransaction; the closure
//     receives a [TransactionalUnitOfWork] bound to an open transaction
//     and every writer resolved through it commits or rolls back
//     together.
//
// Handlers that MUST run inside an open transaction should depend on
// [TransactionalUnitOfWork] directly instead — see that type's docs.
type UnitOfWork interface {
	DoTransaction(ctx context.Context, handler func(ctx context.Context, utx TransactionalUnitOfWork) error) error
	TransactionalUnitOfWork
}

// TransactionalUnitOfWork is the accessor surface a command handler
// sees inside an open transaction. Each method returns a per-aggregate
// Writer bound to the current transaction; mutations made through
// these writers commit or roll back as one unit.
//
// Depending on this narrower interface instead of [UnitOfWork] is a
// type-level statement that the handler MUST run inside a
// DoTransaction closure — it has no way to start a fresh transaction
// or escape into auto-commit mode.
type TransactionalUnitOfWork interface {
	Organizations() organization.Writer
	Staffs() staff.Writer
}
