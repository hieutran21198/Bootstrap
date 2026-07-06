# The RLS bootstrap-read problem, and the `backoffice_authn` answer

> Informal quick-reference (outside the 7 formal `docs/` tracks) — a reusable
> design pattern observed twice in this workspace. Not yet promoted into a
> convention or skill; see "Recommended follow-up" below.

## The problem

Any RLS boundary keyed on an **app-resolved** identity has a bootstrap read:
the lookup that resolves the identity cannot itself require the identity,
because at the moment that lookup runs, the caller only has an external
credential (an OIDC subject, a bearer token) — not yet the internal id
(`organization.ID`, `backofficestaff.ID`) the RLS policy is keyed on. If the
bootstrap lookup is forced through the same role/policy as ordinary
actor-bound reads, it either fails closed for everyone (chicken-and-egg: no
row visible until the id is known, but the id can only be learned from a
row) or the general role/policy has to be widened with a second identity
branch to admit it — which quietly weakens the policy that protects
every *other* read on that role.

This is not one bug; it is a shape that recurs anywhere "resolve who this
caller is" and "act as that caller" are both backed by RLS.

## Where it has been observed

- **Tenant side** — [`docs/conventions/auth/oidc-provider-integration.md`](../conventions/auth/oidc-provider-integration.md)
  (~line 22, "Bootstrap subtlety for that spec"): resolving `Principal.Subject` /
  IdP org to the portal's `organization.ID` + `staff.ID` "must run under a
  scope RLS admits — it cannot be an ordinary org-bound read *before* the org
  is known."
- **Backoffice side** — [`docs/specs/backoffice-authorization-model.md`](../specs/backoffice-authorization-model.md)
  (BF-1 / "Bootstrap actor resolution"): middleware has a provider subject, not
  a `backofficestaff.ID`, so it "must therefore **not** call `DoBackofficeQuery`,
  because that boundary requires an already-resolved actor id for
  `app.backoffice_actor_id`."

Two independent designs, a tenant portal and a backoffice platform surface,
hit the identical shape and had to invent the identical class of answer
independently. That repetition is what makes this a pattern worth writing
down rather than a one-off spec detail.

## The reusable answer: the `backoffice_authn` pattern

Named after where it was made explicit first — [`docs/specs/backoffice-staff-management-surface-and-flows.md`](../specs/backoffice-staff-management-surface-and-flows.md)
§ "Database privilege, RLS, and role/GUC contract" and § "Named application
boundary" — but the shape is general, not backoffice-specific:

Give the pre-authorization identity-resolution lookup **its own minimal
database role**, distinct from the general reader/writer role(s) used after
authorization:

1. **Column-limited `SELECT` only.** Grant `SELECT` on only the columns the
   lookup needs to decide "who is this and are they allowed in" (id, external
   subject, role, active) — never the full row, never `INSERT`/`UPDATE`/`DELETE`.
2. **A subject-keyed row-filtering policy**, not an actor-keyed one. The
   policy admits exactly the row matching the external subject GUC
   (`app.backoffice_subject = current_setting(...)`), so a missing/wrong
   subject fails closed to zero rows — the same fail-closed guarantee as
   every other RLS policy in the contract, just keyed on the pre-authorization
   identity instead of the post-authorization one.
3. **No branch on the general roles.** The general reader/writer role's
   policy is never widened to admit a second identity GUC to accommodate this
   lookup. The bootstrap role is *additive* — one more narrow role — not a
   weakening of the role that protects ordinary actor-bound traffic.
4. **The bootstrap role has no path back to itself.** It cannot list, mutate,
   or iterate rows generally — only resolve one external subject to enough
   fields to construct (or deny) an authorized actor. Every read/write after
   that point switches to the actor-bound role and GUC.

Concretely (backoffice instance): `backoffice_authn` gets column-limited
`SELECT (id, provider_user_id, role, active)` on `backoffice.staff`, gated by
a policy on `app.backoffice_subject`; `backoffice_writer`/`backoffice_reader`
get the ordinary full-row access gated on `app.backoffice_actor_id`, and
`backoffice_authn` has no branch in their policies at all. See
[backoffice-staff-management-surface-and-flows.md](../specs/backoffice-staff-management-surface-and-flows.md)
for the worked SQL and the `ResolveBackofficeActorBySubject` port shape, and
[backoffice-authorization-model.md](../specs/backoffice-authorization-model.md)
for how middleware sequences the bootstrap lookup before actor-bound calls
(both specs also record, in their own "Alternatives considered," the
rejected option of branching the general reader role instead — the reasoning
that motivates rule 3 above).

## Recommended follow-up (not applied by this note)

This note is a wiki-level observation, not yet a rule. Per `docs/wiki/`
convention, promote it to a formal track when it hardens:

- Add the bootstrap-read problem and the `backoffice_authn` answer explicitly
  to [`docs/conventions/database/role-and-scope-contract.md`](../conventions/database/role-and-scope-contract.md)
  (today it only documents the tenant `organization`/`system` scopes) and to
  the [`rls-patterns` skill](../../tools/ai/skills/rls-patterns/SKILL.md)
  (today its worked example is the tenant `staff` table, with no bootstrap-read
  case).
- Flagging as follow-up only, not applied here: a convention change of this
  shape may warrant its own ADR, since it changes what every future
  identity-resolution boundary is expected to do, not just documents current
  behavior.

## References

- [OIDC provider integration convention](../conventions/auth/oidc-provider-integration.md) — tenant-side bootstrap-read subtlety.
- [Backoffice authorization model spec](../specs/backoffice-authorization-model.md) — backoffice-side bootstrap actor resolution (BF-1).
- [Backoffice staff-management surface and flows spec](../specs/backoffice-staff-management-surface-and-flows.md) — the `backoffice_authn` role, grants, and policy this pattern generalizes from.
- [Database role and scope contract](../conventions/database/role-and-scope-contract.md) — the existing role/GUC contract this pattern extends.
- [`rls-patterns` skill](../../tools/ai/skills/rls-patterns/SKILL.md) — the how-to this pattern should be added to.
- [`docs/debt/database/schema-wide-grants-fail-open.md`](../debt/database/schema-wide-grants-fail-open.md) — a related but distinct debt item from the same design review (grant defaults, not identity resolution).
- [`.sdlc/backoffice-staff-management/coordination/adr-acceptance-and-spec-conditions.md`](../../.sdlc/backoffice-staff-management/coordination/adr-acceptance-and-spec-conditions.md) — the review record this note was distilled from.
