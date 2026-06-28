package ssmx_test

import (
	"bootstrap/packages/go/aws/ssmx"
	"context"
	"errors"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"github.com/aws/aws-sdk-go-v2/service/ssm/types"
)

// fakeSSM is an in-memory stub that returns pre-configured pages in order.
// It satisfies the unexported ssmGetter interface via structural typing.
type fakeSSM struct {
	pages  []fakePage
	cursor int
}

type fakePage struct {
	params    []types.Parameter
	nextToken *string
	err       error
}

func (f *fakeSSM) GetParametersByPath(
	_ context.Context,
	_ *ssm.GetParametersByPathInput,
	_ ...func(*ssm.Options),
) (*ssm.GetParametersByPathOutput, error) {
	if f.cursor >= len(f.pages) {
		return &ssm.GetParametersByPathOutput{}, nil
	}

	p := f.pages[f.cursor]
	f.cursor++

	if p.err != nil {
		return nil, p.err
	}

	return &ssm.GetParametersByPathOutput{
		Parameters: p.params,
		NextToken:  p.nextToken,
	}, nil
}

func strPtr(s string) *string { return &s }

// TestLoad_twoPaginationPages verifies that Load collects parameters
// across two pages, following the NextToken.
func TestLoad_twoPaginationPages(t *testing.T) {
	// Given
	const path = "/cirius/platform"
	fake := &fakeSSM{
		pages: []fakePage{
			{
				params: []types.Parameter{
					{Name: strPtr("/cirius/platform/DB_URL"), Value: strPtr("postgres://localhost/db")},
					{Name: strPtr("/cirius/platform/REDIS_URL"), Value: strPtr("redis://localhost:6379")},
				},
				nextToken: aws.String("tok1"),
			},
			{
				params: []types.Parameter{
					{Name: strPtr("/cirius/platform/SECRET"), Value: strPtr("s3cret")},
				},
				nextToken: nil,
			},
		},
	}
	loader := ssmx.New(fake, path)

	// When
	got, err := loader.Load(context.Background())
	// Then
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got) != 3 {
		t.Fatalf("want 3 params, got %d: %v", len(got), got)
	}
}

// TestLoad_prefixStripped verifies that the path prefix and leading "/"
// are removed from parameter names to form map keys.
func TestLoad_prefixStripped(t *testing.T) {
	// Given
	const path = "/cirius/platform"
	fake := &fakeSSM{
		pages: []fakePage{
			{
				params: []types.Parameter{
					{Name: strPtr("/cirius/platform/DB_URL"), Value: strPtr("postgres://localhost/db")},
				},
			},
		},
	}
	loader := ssmx.New(fake, path)

	// When
	got, err := loader.Load(context.Background())
	// Then
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	val, ok := got["DB_URL"]
	if !ok {
		t.Fatalf("key DB_URL not found in %v", got)
	}
	if val != "postgres://localhost/db" {
		t.Fatalf("want DB_URL=%q, got %q", "postgres://localhost/db", val)
	}
}

// TestLoad_nilName_skipped verifies that parameters with nil Name are
// silently skipped without panicking.
func TestLoad_nilName_skipped(t *testing.T) {
	// Given
	const path = "/cirius/platform"
	fake := &fakeSSM{
		pages: []fakePage{
			{
				params: []types.Parameter{
					{Name: nil, Value: strPtr("orphan")},
					{Name: strPtr("/cirius/platform/KEY"), Value: strPtr("val")},
				},
			},
		},
	}
	loader := ssmx.New(fake, path)

	// When
	got, err := loader.Load(context.Background())
	// Then
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("want 1 entry (nil Name skipped), got %d: %v", len(got), got)
	}
	if _, ok := got["KEY"]; !ok {
		t.Fatalf("want key KEY present, got %v", got)
	}
}

// TestLoad_nilValue_yieldsEmptyString verifies that a parameter with
// a nil Value is stored as an empty string in the result map.
func TestLoad_nilValue_yieldsEmptyString(t *testing.T) {
	// Given
	const path = "/cirius/platform"
	fake := &fakeSSM{
		pages: []fakePage{
			{
				params: []types.Parameter{
					{Name: strPtr("/cirius/platform/EMPTY"), Value: nil},
				},
			},
		},
	}
	loader := ssmx.New(fake, path)

	// When
	got, err := loader.Load(context.Background())
	// Then
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	val, ok := got["EMPTY"]
	if !ok {
		t.Fatalf("key EMPTY not found in %v", got)
	}
	if val != "" {
		t.Fatalf("want empty string for nil Value, got %q", val)
	}
}

// TestLoad_errorOnSecondPage_propagated verifies that an SDK error on
// any page is returned as a wrapped error from Load.
func TestLoad_errorOnSecondPage_propagated(t *testing.T) {
	// Given
	const path = "/cirius/platform"
	sentinel := errors.New("ssm: access denied")
	fake := &fakeSSM{
		pages: []fakePage{
			{
				params:    []types.Parameter{{Name: strPtr("/cirius/platform/K"), Value: strPtr("v")}},
				nextToken: aws.String("tok"),
			},
			{err: sentinel},
		},
	}
	loader := ssmx.New(fake, path)

	// When
	_, err := loader.Load(context.Background())

	// Then
	if err == nil {
		t.Fatal("want error, got nil")
	}
	if !errors.Is(err, sentinel) {
		t.Fatalf("want error wrapping sentinel, got %v", err)
	}
}
