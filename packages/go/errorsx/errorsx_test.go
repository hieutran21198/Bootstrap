package errorsx_test

import (
	"errors"
	"fmt"
	"strings"
	"testing"

	"bootstrap/packages/go/errorsx"
)

func TestNew_SetsCodeAndMessage(t *testing.T) {
	t.Parallel()
	err := errorsx.New(errorsx.CodeInvalid, "bad input")
	if err.Code != errorsx.CodeInvalid {
		t.Errorf("Code = %q; want %q", err.Code, errorsx.CodeInvalid)
	}
	if err.Message != "bad input" {
		t.Errorf("Message = %q; want %q", err.Message, "bad input")
	}
	if len(err.FieldErrors) != 0 {
		t.Errorf("FieldErrors = %v; want empty", err.FieldErrors)
	}
	if got := err.Unwrap(); got != nil {
		t.Errorf("Unwrap() = %v; want nil", got)
	}
}

func TestError_String(t *testing.T) {
	t.Parallel()
	cause := errors.New("boom")
	cases := []struct {
		name string
		err  errorsx.Error
		want string
	}{
		{
			name: "code and message",
			err:  errorsx.New(errorsx.CodeInvalid, "bad input"),
			want: "invalid: bad input",
		},
		{
			name: "code only",
			err:  errorsx.New(errorsx.CodeNotFound, ""),
			want: "not_found",
		},
		{
			name: "zero value",
			err:  errorsx.Error{},
			want: "errorsx: empty error",
		},
		{
			name: "single field error",
			err:  errorsx.New(errorsx.CodeInvalid, "bad").WithFields(errorsx.FieldError{Location: "body.email"}),
			want: "invalid: bad (1 field error)",
		},
		{
			name: "multiple field errors",
			err: errorsx.New(errorsx.CodeInvalid, "bad").WithFields(
				errorsx.FieldError{Location: "body.email"},
				errorsx.FieldError{Location: "body.name"},
			),
			want: "invalid: bad (2 field errors)",
		},
		{
			name: "internal cause is not rendered",
			err:  errorsx.New(errorsx.CodeInternal, "failed").WithInternal(cause),
			want: "internal: failed",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if got := tc.err.Error(); got != tc.want {
				t.Errorf("Error() = %q; want %q", got, tc.want)
			}
		})
	}
}

func TestWithInternal_UnwrapAndIs(t *testing.T) {
	t.Parallel()
	sentinel := errors.New("root cause")
	err := errorsx.New(errorsx.CodeInternal, "failed").WithInternal(sentinel)

	if got := err.Unwrap(); !errors.Is(got, sentinel) {
		t.Errorf("Unwrap() = %v; want %v", got, sentinel)
	}
	if !errors.Is(err, sentinel) {
		t.Errorf("errors.Is did not match wrapped sentinel")
	}
}

func TestUnwrap_NilWhenNoInternal(t *testing.T) {
	t.Parallel()
	err := errorsx.New(errorsx.CodeInvalid, "bad")
	if got := err.Unwrap(); got != nil {
		t.Errorf("Unwrap() = %v; want nil", got)
	}
}

func TestWithFields_AppendsAndDoesNotMutateReceiver(t *testing.T) {
	t.Parallel()
	base := errorsx.New(errorsx.CodeInvalid, "bad")
	withOne := base.WithFields(errorsx.FieldError{
		Location: "body.email",
		Value:    "not-an-email",
		Message:  "must be a valid email",
	})
	withTwo := withOne.WithFields(errorsx.FieldError{Location: "body.name"})

	if len(base.FieldErrors) != 0 {
		t.Errorf("base mutated: FieldErrors = %v; want empty", base.FieldErrors)
	}
	if len(withOne.FieldErrors) != 1 {
		t.Fatalf("withOne.FieldErrors len = %d; want 1", len(withOne.FieldErrors))
	}
	if len(withTwo.FieldErrors) != 2 {
		t.Fatalf("withTwo.FieldErrors len = %d; want 2", len(withTwo.FieldErrors))
	}

	fe := withOne.FieldErrors[0]
	if fe.Location != "body.email" || fe.Value != "not-an-email" || fe.Message != "must be a valid email" {
		t.Errorf("FieldError = %+v; want populated body.email failure", fe)
	}
}

func TestWith_ClonesOrigin(t *testing.T) {
	t.Parallel()
	base := errorsx.New(errorsx.CodeInvalid, "bad").WithFields(
		errorsx.FieldError{Location: "body.email", Message: "required"},
	)

	// WithInternal must clone: mutating an element of the derived error's
	// FieldErrors must not leak back into base's shared backing array.
	derived := base.WithInternal(errors.New("cause"))
	derived.FieldErrors[0].Message = "CHANGED"
	if base.FieldErrors[0].Message != "required" {
		t.Errorf("WithInternal did not clone: base field mutated to %q", base.FieldErrors[0].Message)
	}

	// WithFields must clone: appending through the derived error must not
	// overwrite base's element even if spare capacity exists.
	more := base.WithFields(errorsx.FieldError{Location: "body.name"})
	more.FieldErrors[0].Message = "ALSO CHANGED"
	if base.FieldErrors[0].Message != "required" {
		t.Errorf("WithFields did not clone: base field mutated to %q", base.FieldErrors[0].Message)
	}
	if len(base.FieldErrors) != 1 {
		t.Errorf("base length changed to %d; want 1", len(base.FieldErrors))
	}
}

func TestErrorsAs_MatchesThroughWrap(t *testing.T) {
	t.Parallel()
	sentinel := errors.New("root cause")
	original := errorsx.New(errorsx.CodeConflict, "duplicate").WithInternal(sentinel)
	wrapped := fmt.Errorf("service layer: %w", error(original))

	var target errorsx.Error
	if !errors.As(wrapped, &target) {
		t.Fatalf("errors.As did not match errorsx.Error through fmt wrap")
	}
	if target.Code != errorsx.CodeConflict {
		t.Errorf("Code = %q; want %q", target.Code, errorsx.CodeConflict)
	}
	if !errors.Is(wrapped, sentinel) {
		t.Errorf("errors.Is did not reach sentinel through both wraps")
	}
}

func TestFieldError_InternalViaUnwrap(t *testing.T) {
	t.Parallel()
	cause := errors.New("strconv: invalid syntax")
	fe := errorsx.FieldError{
		Location: "query.page",
		Value:    "abc",
		Message:  "must be an integer",
	}.WithInternal(cause)

	if got := fe.Unwrap(); !errors.Is(got, cause) {
		t.Errorf("FieldError.Unwrap() = %v; want %v", got, cause)
	}
}

func TestNewField(t *testing.T) {
	t.Parallel()

	// No internal cause; Value carries a non-string typed value.
	fe := errorsx.NewField("query.page", "must be an integer", 42)
	if fe.Location != "query.page" {
		t.Errorf("Location = %q; want %q", fe.Location, "query.page")
	}
	if fe.Message != "must be an integer" {
		t.Errorf("Message = %q; want %q", fe.Message, "must be an integer")
	}
	if fe.Value != 42 {
		t.Errorf("Value = %v; want 42", fe.Value)
	}
	if got := fe.Unwrap(); got != nil {
		t.Errorf("Unwrap() = %v; want nil", got)
	}

	// Only the first internal cause is used; the rest are ignored.
	cause := errors.New("root cause")
	ignored := errors.New("ignored")
	fe2 := errorsx.NewField("body.email", "required", "", cause, ignored)
	if got := fe2.Unwrap(); !errors.Is(got, cause) {
		t.Errorf("Unwrap() = %v; want %v", got, cause)
	}
	if errors.Is(fe2.Unwrap(), ignored) {
		t.Errorf("Unwrap() unexpectedly matched the ignored cause")
	}
}

func TestFieldError_WithInternalClonesReceiver(t *testing.T) {
	t.Parallel()
	base := errorsx.NewField("loc", "msg", "val")
	derived := base.WithInternal(errors.New("cause"))

	if got := base.Unwrap(); got != nil {
		t.Errorf("WithInternal mutated receiver: base.Unwrap() = %v; want nil", got)
	}
	if got := derived.Unwrap(); got == nil {
		t.Errorf("derived.Unwrap() = nil; want a cause")
	}
}

func TestError_DoesNotLeakInternal(t *testing.T) {
	t.Parallel()
	const secret = "secret-db-detail"
	cause := errors.New(secret)
	err := errorsx.New(errorsx.CodeInternal, "failed").
		WithInternal(cause).
		WithFields(errorsx.FieldError{Location: "body.x", Message: "bad"}.WithInternal(errors.New("field-secret")))

	got := err.Error()
	if strings.Contains(got, secret) || strings.Contains(got, "field-secret") {
		t.Errorf("Error() leaked an internal cause: %q", got)
	}
	// The top-level cause stays reachable through the controlled Unwrap seam.
	if !errors.Is(err, cause) {
		t.Errorf("errors.Is could not reach internal cause via Unwrap")
	}
}
