package idgen_test

import (
	"testing"

	"github.com/google/uuid"

	"bootstrap/packages/go/idgen"
)

// testID is a stand-in for a domain aggregate ID type.
type testID string

func TestNewFor_NotEmpty(t *testing.T) {
	t.Parallel()
	id := idgen.NewFor[testID]()
	if id == "" {
		t.Fatal("NewFor returned empty id")
	}
}

// requireTestID accepts testID only. Calling it with the result of
// NewFor verifies at compile time that NewFor[testID] returns testID,
// not a raw string — if NewFor's signature were `func NewFor() string`,
// the call inside TestNewFor_ReturnsTypedID would fail to compile.
func requireTestID(id testID) testID { return id }

func TestNewFor_ReturnsTypedID(t *testing.T) {
	t.Parallel()
	got := requireTestID(idgen.NewFor[testID]())
	if got == "" {
		t.Fatal("got empty id")
	}
}

func TestNewFor_IsUUIDv7(t *testing.T) {
	t.Parallel()
	id := idgen.NewFor[testID]()
	parsed, err := uuid.Parse(string(id))
	if err != nil {
		t.Fatalf("NewFor produced %q: %v", id, err)
	}
	if parsed.Version() != 7 {
		t.Errorf("NewFor produced UUID v%d, want v7", parsed.Version())
	}
}

func TestNewFor_Unique(t *testing.T) {
	t.Parallel()
	const n = 1000
	seen := make(map[testID]struct{}, n)
	for range n {
		id := idgen.NewFor[testID]()
		if _, dup := seen[id]; dup {
			t.Fatalf("duplicate id generated within %d samples: %q", n, id)
		}
		seen[id] = struct{}{}
	}
}

func TestValidate_AcceptsGeneratedID(t *testing.T) {
	t.Parallel()
	id := idgen.NewFor[testID]()
	if err := idgen.Validate(id); err != nil {
		t.Fatalf("Validate rejected generated id %q: %v", id, err)
	}
}

func TestValidate_RejectsNonUUID(t *testing.T) {
	t.Parallel()
	cases := []testID{
		"",
		"not-a-uuid",
		"12345",
		"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
	}
	for _, id := range cases {
		if err := idgen.Validate(id); err == nil {
			t.Errorf("Validate accepted non-UUID %q, want error", id)
		}
	}
}

func TestValidate_RejectsWrongVersion(t *testing.T) {
	t.Parallel()
	// uuid.New() returns UUIDv4, which Validate must reject.
	v4 := testID(uuid.New().String())
	err := idgen.Validate(v4)
	if err == nil {
		t.Fatalf("Validate accepted UUIDv4 %q, want error", v4)
	}
}
