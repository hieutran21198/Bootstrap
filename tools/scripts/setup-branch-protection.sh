#!/usr/bin/env bash
# setup-branch-protection.sh — apply the server-side half of the Git conventions
# (docs/conventions/git/, ADR-0012) that local hooks and CI cannot enforce:
#
#   • main and release/* require a PR, an approving review, and passing CI
#     ("Git conventions" from .github/workflows/pr-validate.yml)
#   • direct pushes, force-pushes, and deletion of those branches are blocked
#   • the repo allows ONLY squash-merge, and deletes branches on merge
#
# Requires: gh (authenticated with admin on the repo) and jq. Idempotent:
# re-running updates the existing rulesets in place.
#
# Usage:
#   tools/scripts/setup-branch-protection.sh            # apply
#   tools/scripts/setup-branch-protection.sh --dry-run  # print payloads only
set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

command -v gh >/dev/null || { echo "error: gh CLI not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq not found" >&2; exit 1; }

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
CHECK_CONTEXT="Git conventions"   # job name in .github/workflows/pr-validate.yml
echo "Repository: $REPO"

# Build a branch-ruleset payload. $1 = ruleset name, $2 = ref include pattern.
ruleset_payload() {
  jq -n --arg name "$1" --arg ref "$2" --arg check "$CHECK_CONTEXT" '{
    name: $name,
    target: "branch",
    enforcement: "active",
    conditions: { ref_name: { include: [$ref], exclude: [] } },
    rules: [
      { type: "deletion" },
      { type: "non_fast_forward" },
      { type: "pull_request", parameters: {
          required_approving_review_count: 1,
          dismiss_stale_reviews_on_push: true,
          require_code_owner_review: false,
          require_last_push_approval: false,
          required_review_thread_resolution: false
      } },
      { type: "required_status_checks", parameters: {
          strict_required_status_checks_policy: true,
          required_status_checks: [ { context: $check } ]
      } }
    ]
  }'
}

# Create the ruleset, or update it in place if one with the same name exists.
apply_ruleset() {
  local name="$1" ref="$2" payload id
  payload="$(ruleset_payload "$name" "$ref")"
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "--- ruleset: $name ($ref) ---"; echo "$payload"; return
  fi
  id="$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$name\") | .id" 2>/dev/null || true)"
  if [[ -n "$id" ]]; then
    echo "Updating ruleset '$name' (id $id)"
    echo "$payload" | gh api --method PUT "repos/$REPO/rulesets/$id" --input - >/dev/null
  else
    echo "Creating ruleset '$name'"
    echo "$payload" | gh api --method POST "repos/$REPO/rulesets" --input - >/dev/null
  fi
}

# Repo merge policy: squash-only, tidy branches.
apply_merge_policy() {
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "--- repo merge policy: squash-only + delete-branch-on-merge ---"; return
  fi
  echo "Setting merge policy (squash-only, delete branch on merge)"
  gh api --method PATCH "repos/$REPO" \
    -F allow_squash_merge=true \
    -F allow_merge_commit=false \
    -F allow_rebase_merge=false \
    -F delete_branch_on_merge=true >/dev/null
}

apply_merge_policy
apply_ruleset "main protection"    "refs/heads/main"
apply_ruleset "release protection" "refs/heads/release/**"

echo "Done."
