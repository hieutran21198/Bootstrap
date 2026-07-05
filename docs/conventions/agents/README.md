# Agent conventions

Workspace-wide rules for AI-agent hand-offs, review loops, and local scratch
artifacts. This topic is separate from `delivery/`: delivery rules govern Linear
state and close-out evidence, while agent rules govern how orchestrated sessions
exchange context across every SDLC stage.

> **Scope**: every AI agent and orchestrated hand-off that performs or reviews work in this workspace.
> **Status**: Active
> **Decided by**: [ADR-0021](../../adrs/0021-artifact-mediated-agent-communication-and-sdlc-scratch-workspace.md)
> **Last reviewed**: 2026-07-05

## Index

| #   | Document                                                            | One-liner                                                                                                      |
| --- | ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| 1   | [Artifact-mediated communication](artifact-mediated-communication.md) | Agent context moves through orchestrator-routed disk/Linear artifacts; `.sdlc/` is disposable deliberation space. |

## See also

- [ADR-0021](../../adrs/0021-artifact-mediated-agent-communication-and-sdlc-scratch-workspace.md) — the decision that established this topic.
- [Workspace conventions index](../README.md) — sibling topics.
- [Implementation workflow](../../wiki/implementation-workflow.md) — SDLC pipeline and human gates.
- [Agent team quick reference](../../wiki/agent-team.md) — current agent roster and responsibilities.
