// Package errorsx provides a structured, transport-neutral application error.
//
// An [Error] carries a typed [Code] that classifies the failure independently
// of any transport — it is deliberately NOT an HTTP status — a human-readable
// Message, and zero or more field-level failures ([FieldError]). It may also
// carry an unexported internal cause for diagnostics. That cause is never part
// of the public surface — it is not an exported field, is not serialized, and
// is not rendered by [Error.Error] — and is reachable only through
// [Error.Unwrap]. Adapter and logging layers can therefore record it
// out-of-band (e.g. at debug level) while it can never leak into a
// client-facing payload. Boundary layers (HTTP handlers, gRPC/Connect
// interceptors, ...) map [Code] to a transport status and decide what to
// expose.
//
// This is a stateless package: its API is pure types and functions, not a
// constructable target. See docs/conventions/go/single-responsibility.md for
// the category description.
package errorsx

import (
	"slices"
	"strconv"
	"strings"
)

// Code classifies an [Error] by kind, independent of any transport. It is an
// open string type: the constants below are a canonical starting palette that
// callers may extend with their own values.
type Code string

// Canonical, transport-neutral error codes. Map these to a transport status
// (HTTP, gRPC, ...) at the boundary; do not treat them as status codes here.
const (
	// CodeInvalid indicates malformed or semantically invalid input.
	CodeInvalid Code = "invalid"
	// CodeNotFound indicates the requested resource does not exist.
	CodeNotFound Code = "not_found"
	// CodeConflict indicates a state conflict, such as a duplicate or a
	// version clash.
	CodeConflict Code = "conflict"
	// CodeUnauthenticated indicates missing or invalid credentials.
	CodeUnauthenticated Code = "unauthenticated"
	// CodePermissionDenied indicates the caller is authenticated but not
	// permitted to perform the operation.
	CodePermissionDenied Code = "permission_denied"
	// CodeInternal indicates an unexpected internal failure.
	CodeInternal Code = "internal"
)

// FieldError describes a single field-level failure, typically produced during
// input validation. Its Location, Value, and Message are client-safe; the
// underlying cause is kept unexported so it cannot leak.
type FieldError struct {
	// Location identifies the offending field, e.g. "body.email" or
	// "query.page". The format is caller-defined.
	Location string
	// Value is the rejected value. Its type is any so callers can attach the
	// original typed value; omit or redact it for sensitive fields.
	Value any
	// Message is a human-readable, client-safe explanation of the failure.
	Message string
	// internal is the underlying cause (e.g. a strconv error). It is
	// unexported so it never leaks into a serialized or client-facing payload;
	// set it with [FieldError.WithInternal], read it with [FieldError.Unwrap].
	internal error
}

// NewField builds a [FieldError] for the field at loc with message msg and the
// rejected value val. An optional internal cause may be supplied; only the
// first is used and the rest are ignored. The cause is stored unexported and is
// reachable only via [FieldError.Unwrap].
func NewField(loc, msg string, val any, internal ...error) FieldError {
	fe := FieldError{Location: loc, Message: msg, Value: val}
	if len(internal) > 0 {
		fe.internal = internal[0]
	}
	return fe
}

// WithInternal returns an independent copy of fe with its internal cause set to
// err. The receiver is left unmodified; because FieldError holds no slices or
// maps, the value copy is a complete clone (any reference held in Value, or the
// cause itself, is shared rather than deep-copied).
func (fe FieldError) WithInternal(err error) FieldError {
	fe.internal = err
	return fe
}

// Unwrap returns fe's internal cause, or nil when none is set. It is the only
// way to read the cause: the field is unexported, so the cause is never
// serialized or rendered. Adapter and logging layers call it to record the
// cause out-of-band.
func (fe FieldError) Unwrap() error {
	return fe.internal
}

// Error is a structured, transport-neutral application error.
//
// The zero value is a valid but empty error; prefer [New] to construct one.
// Its methods use value receivers and return a new Error, so both Error and
// *Error satisfy the error interface and match errors.As, and builder calls
// must be chained or reassigned (value semantics, like time.Time).
type Error struct {
	// Code classifies the failure. See the Code constants.
	Code Code
	// Message is a human-readable, client-safe explanation.
	Message string
	// FieldErrors holds zero or more field-level failures.
	FieldErrors []FieldError
	// internal is the underlying cause. It is unexported so it never leaks into
	// a serialized or client-facing payload; set it with [Error.WithInternal]
	// and read it with [Error.Unwrap], which also lets it participate in
	// errors.Is / errors.As.
	internal error
}

// New returns an [Error] with the given code and message. Attach a cause with
// [Error.WithInternal] and field failures with [Error.WithFields].
func New(code Code, message string) Error {
	return Error{Code: code, Message: message}
}

// clone returns an independent copy of e: the struct is copied and its
// FieldErrors slice is reallocated so the result shares no backing array with
// e. The internal causes (e's own and each field's) are copied by reference —
// the container is cloned, not the underlying errors.
func (e Error) clone() Error {
	c := e
	c.FieldErrors = slices.Clone(e.FieldErrors)
	return c
}

// WithInternal clones e and sets the clone's internal cause to err. The
// receiver is left unmodified and shares no state with the returned Error.
func (e Error) WithInternal(err error) Error {
	c := e.clone()
	c.internal = err
	return c
}

// WithFields clones e and appends fields to the clone's FieldErrors. The
// receiver is left unmodified and shares no state with the returned Error.
func (e Error) WithFields(fields ...FieldError) Error {
	c := e.clone()
	c.FieldErrors = append(c.FieldErrors, fields...)
	return c
}

// Error implements the error interface. The rendered string is client-safe: it
// reports the code, message, and field-error count, but never the internal
// cause, which is reachable only via [Error.Unwrap].
func (e Error) Error() string {
	var b strings.Builder
	if e.Code != "" {
		b.WriteString(string(e.Code))
	}
	if e.Message != "" {
		if b.Len() > 0 {
			b.WriteString(": ")
		}
		b.WriteString(e.Message)
	}
	if b.Len() == 0 {
		b.WriteString("errorsx: empty error")
	}
	if n := len(e.FieldErrors); n > 0 {
		b.WriteString(" (")
		b.WriteString(strconv.Itoa(n))
		if n == 1 {
			b.WriteString(" field error)")
		} else {
			b.WriteString(" field errors)")
		}
	}
	return b.String()
}

// Unwrap returns e's internal cause, or nil when none is set. It is the only
// way to read the cause: the field is unexported, so the cause is never
// serialized or rendered by [Error.Error]. It also lets the internal cause
// participate in errors.Is and errors.As, and lets adapter and logging layers
// record it out-of-band (e.g. at debug level) without leaking it to clients.
func (e Error) Unwrap() error {
	return e.internal
}
