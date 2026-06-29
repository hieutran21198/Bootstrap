package query

import (
	"context"
	"errors"

	"bootstrap/services/portal/internal/domain/organization"
)

// System-scope capability gate (ADR-0009).
//
// The `system` RLS scope lets a cross-tenant consumer (a platform-wide
// worker, or a future back-office service) read rows across all
// organizations. Because that is a sharp tool — a bug runs against every
// tenant at once — *binding* the scope requires an unforgeable, typed
// capability that only a [SystemScopeAuthorizer] can mint. Scope stays a
// property of the unit of work (any caller may choose it), but the
// system entry point's signature demands a capability no caller can
// fabricate, so authorization is enforced at the application layer while
// RLS enforces the data boundary.
//
// This is read-only by design: there is a DoSystemQuery, deliberately no
// DoSystemTransaction. System writes need their own ADR, role, and
// capability (ADR-0009).

// ErrEmptySystemPurpose is returned when a capability is requested
// without a non-empty purpose. Every system-scoped read must record why
// it crossed the tenant boundary, for audit.
var ErrEmptySystemPurpose = errors.New("query: empty system scope purpose")

// SystemPrincipalKind enumerates who may hold a system capability. Only
// `worker` exists today; an `operator` kind (a human via the future
// back-office) is reserved for when that consumer exists.
type SystemPrincipalKind string

const (
	// SystemPrincipalWorker is a non-interactive cross-tenant job.
	SystemPrincipalWorker SystemPrincipalKind = "worker"
)

// SystemPrincipal identifies the caller requesting cross-tenant access.
type SystemPrincipal struct {
	Kind    SystemPrincipalKind
	Subject string // worker name (or, later, operator id)
}

// SystemTarget is the set of organizations a capability authorizes. It
// has no exported fields and is constructed only via [AllOrganizations]
// or [OnlyOrganizations], so a caller cannot widen the target after the
// authorizer set it.
type SystemTarget struct {
	all bool
	ids []organization.ID
}

// AllOrganizations targets every tenant — an explicit, audited choice
// (it maps to the `*` allowlist). Prefer [OnlyOrganizations] whenever the
// job needs only a subset.
func AllOrganizations() SystemTarget {
	return SystemTarget{all: true}
}

// OnlyOrganizations targets a bounded set of tenants. The capability
// carries this list into the RLS allowlist so visibility is shrunk from
// "all tenants" to exactly these ids.
func OnlyOrganizations(ids []organization.ID) SystemTarget {
	cp := make([]organization.ID, len(ids))
	copy(cp, ids)
	return SystemTarget{all: false, ids: cp}
}

// IsAll reports whether the target is every organization.
func (t SystemTarget) IsAll() bool { return t.all }

// IDs returns a copy of the targeted organization ids (empty when
// [IsAll] is true).
func (t SystemTarget) IDs() []organization.ID {
	cp := make([]organization.ID, len(t.ids))
	copy(cp, t.ids)
	return cp
}

// SystemReadCapability is proof that a caller was authorized to bind the
// `system` read scope for a specific target. Its fields are unexported
// and it is minted only by a [SystemScopeAuthorizer], so it cannot be
// forged; the carried target is what the binder applies, so a caller
// cannot authorize one target and bind another.
type SystemReadCapability struct {
	principal SystemPrincipal
	target    SystemTarget
	purpose   string
	minted    bool // false for the zero value — a forged/empty capability
}

// Principal returns the capability's principal.
func (c SystemReadCapability) Principal() SystemPrincipal { return c.principal }

// Target returns the organizations the capability authorizes.
func (c SystemReadCapability) Target() SystemTarget { return c.target }

// Purpose returns the audited reason the capability was minted.
func (c SystemReadCapability) Purpose() string { return c.purpose }

// IsValid reports whether the capability was minted by an authorizer (as
// opposed to a zero-value/forged struct). Binders MUST reject a
// capability for which this returns false.
func (c SystemReadCapability) IsValid() bool { return c.minted }

// NewSystemReadCapability mints a capability. It is the ONLY constructor
// and is intended to be called from a [SystemScopeAuthorizer]
// implementation after it has authorized the principal+target — never
// directly from a handler. Returns [ErrEmptySystemPurpose] when purpose
// is empty.
func NewSystemReadCapability(p SystemPrincipal, target SystemTarget, purpose string) (SystemReadCapability, error) {
	if purpose == "" {
		return SystemReadCapability{}, ErrEmptySystemPurpose
	}
	return SystemReadCapability{
		principal: p,
		target:    target,
		purpose:   purpose,
		minted:    true,
	}, nil
}

// SystemScopeAuthorizer decides whether a principal may bind the
// `system` read scope for a given target, and mints a
// [SystemReadCapability] when allowed. Implementations live in the app
// or infra layer (e.g. an allowlist of permitted worker names); the
// decision is application-layer authorization, distinct from the RLS
// data boundary. The domain never sees principals.
type SystemScopeAuthorizer interface {
	AuthorizeSystemRead(
		ctx context.Context,
		principal SystemPrincipal,
		target SystemTarget,
		purpose string,
	) (SystemReadCapability, error)
}
