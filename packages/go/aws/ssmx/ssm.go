// Package ssmx provides an AWS Parameter Store loader that satisfies
// the env.Loader interface structurally
// (Load(context.Context) (map[string]string, error)) without importing it.
package ssmx

import (
	"context"
	"fmt"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
)

// compile-time proof that *Loader satisfies the env.Loader signature
// without importing cirius-platform/backend/packages/go/env.
var _ interface {
	Load(context.Context) (map[string]string, error)
} = (*Loader)(nil)

// ssmGetter is the minimal SSM client surface Loader needs.
// *ssm.Client from the AWS SDK satisfies this interface.
type ssmGetter interface {
	GetParametersByPath(
		ctx context.Context,
		in *ssm.GetParametersByPathInput,
		optFns ...func(*ssm.Options),
	) (*ssm.GetParametersByPathOutput, error)
}

// Loader fetches parameters from AWS Parameter Store under a path prefix
// and presents them as a flat map[string]string with the prefix stripped.
type Loader struct {
	client ssmGetter
	path   string
}

// New constructs a Loader from an existing SSM client and a path prefix.
func New(client ssmGetter, path string) *Loader {
	return &Loader{client: client, path: path}
}

// NewFromEnv constructs a Loader using the default AWS credential chain
// (IAM role, ~/.aws/credentials, env vars, EC2 instance metadata, …).
// The caller supplies the SSM path prefix explicitly.
func NewFromEnv(ctx context.Context, path string) (*Loader, error) {
	awsCfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("ssmx: load default AWS config: %w", err)
	}

	return New(ssm.NewFromConfig(awsCfg), path), nil
}

// Load pages through Parameter Store under l.path and returns a
// map of key → value.  The l.path prefix (plus any leading "/") is
// stripped from each parameter name to form the map key.
// Parameters with a nil Name are silently skipped; a nil Value yields "".
func (l *Loader) Load(ctx context.Context) (map[string]string, error) {
	result := make(map[string]string)

	in := &ssm.GetParametersByPathInput{
		Path:           aws.String(l.path),
		Recursive:      aws.Bool(true),
		WithDecryption: aws.Bool(true),
	}

	for {
		out, err := l.client.GetParametersByPath(ctx, in)
		if err != nil {
			return nil, fmt.Errorf("ssmx: GetParametersByPath: %w", err)
		}

		for _, param := range out.Parameters {
			if param.Name == nil {
				continue
			}

			key := strings.TrimPrefix(aws.ToString(param.Name), l.path)
			key = strings.TrimPrefix(key, "/")

			value := ""
			if param.Value != nil {
				value = *param.Value
			}

			result[key] = value
		}

		if out.NextToken == nil {
			break
		}

		in.NextToken = out.NextToken
	}

	return result, nil
}
