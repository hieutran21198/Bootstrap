/**
 * Handoff audit log plugin for opencode.
 *
 * Captures every `task` tool invocation as a paired brief/report under
 * `.sdlc/<task-slug>/handoffs/`. Passive: never mutates args, never throws
 * from hooks, logs diagnostics through `client.app.log`.
 *
 * Spec: docs/specs/handoff-audit-log.md
 * Convention: docs/conventions/agents/artifact-mediated-communication.md
 *
 * UPSTREAM PLUGIN CONTRACT (v1.2.x):
 * The opencode v1 plugin API expects the exported function to return the hooks
 * object directly (not wrapped in { name, hooks }). The hook signatures are:
 *
 *   "tool.execute.before"?: (input: { tool, sessionID, callID }, output: { args }) => Promise<void>
 *   "tool.execute.after"?:  (input: { tool, sessionID, callID, args }, output: { title, output, metadata }) => Promise<void>
 *   "chat.message"?:        (input: { sessionID, agent? }, output: unknown) => Promise<void>
 *
 * Hooks are awaited; throwing from tool.execute.before blocks the tool call.
 * This plugin wraps every hook in try/catch and logs via client.app.log.
 */

import { existsSync, mkdirSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// ============================================================================
// Types
// ============================================================================

interface PluginContext {
  client: {
    app: {
      log: (entry: {
        body: {
          service: string;
          level: "info" | "warn" | "error";
          message: string;
          extra?: Record<string, unknown>;
        };
      }) => void;
    };
  };
  project?: { name?: string };
  directory: string;
  worktree?: string;
  serverUrl?: string;
  $?: unknown;
  experimental_workspace?: unknown;
}

/**
 * v1 plugin return type: the hooks object directly (not { name, hooks }).
 */
interface Hooks {
  "tool.execute.before"?: (
    input: { tool: string; sessionID: string; callID: string },
    output: { args: unknown },
  ) => Promise<void>;
  "tool.execute.after"?: (
    input: {
      tool: string;
      sessionID: string;
      callID: string;
      args: unknown;
    },
    output: { title: string; output: string; metadata: unknown },
  ) => Promise<void>;
  "chat.message"?: (
    input: { sessionID: string; agent?: string },
    output: unknown,
  ) => Promise<void>;
}

type PluginFactory = (ctx: PluginContext) => Promise<Hooks>;

interface TaskArgs {
  prompt?: string;
  subagent_type?: string;
  description?: string;
  task_id?: string;
  [key: string]: unknown;
}

interface BeforeRecord {
  sequence: number;
  agent: string;
  briefPath: string;
  reportPath: string;
  beforeTimestamp: string;
  argsSnapshot: Record<string, unknown>;
}

// ============================================================================
// Pure helpers
// ============================================================================

const SERVICE = "handoff-audit-log";

/**
 * Sanitize a string for use in filenames. Replace unsafe characters with `-`.
 */
function sanitizeFilename(s: string): string {
  return s.replace(/[^a-zA-Z0-9._-]/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "");
}

/**
 * Slugify a Git branch name for use as a task slug.
 */
function slugifyBranch(branch: string): string {
  return sanitizeFilename(branch.replace(/\//g, "-"));
}

/**
 * Infer the task slug from the plugin context.
 *
 * Priority:
 * 1. Active Git branch (if work branch) → slugified
 * 2. Worktree directory name (if under .worktrees/)
 * 3. session-<short-sessionID>
 */
function inferTaskSlug(ctx: {
  directory: string;
  worktree?: string;
  sessionID: string;
}): string {
  // Try to get the current Git branch
  try {
    const { execSync } = require("node:child_process");
    const branch = execSync("git rev-parse --abbrev-ref HEAD", {
      cwd: ctx.worktree || ctx.directory,
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();

    // Check if it's a work branch (not main, not release/*, not detached)
    if (
      branch &&
      branch !== "main" &&
      branch !== "HEAD" &&
      !branch.startsWith("release/")
    ) {
      return slugifyBranch(branch);
    }
  } catch {
    // Git not available or not in a repo; fall through
  }

  // Check if worktree path is under .worktrees/
  const worktreePath = ctx.worktree || ctx.directory;
  const worktreesMatch = worktreePath.match(/\.worktrees\/([^/]+)/);
  if (worktreesMatch) {
    return sanitizeFilename(worktreesMatch[1]);
  }

  // Fall back to session-based slug
  const shortSession = ctx.sessionID.slice(0, 8);
  return `session-${shortSession}`;
}

/**
 * Resolve the scratch root (.sdlc/) relative to the worktree or directory.
 */
function resolveScratchRoot(ctx: { directory: string; worktree?: string }): string {
  const base = ctx.worktree || ctx.directory;
  return join(base, ".sdlc");
}

/**
 * Allocate the next sequence number for a handoff directory.
 * Scans existing files for the highest NN- prefix and returns NN+1.
 */
function allocateSequence(handoffDir: string): number {
  if (!existsSync(handoffDir)) {
    return 1;
  }

  const files = readdirSync(handoffDir);
  let maxSeq = 0;

  for (const file of files) {
    const match = file.match(/^(\d+)-/);
    if (match) {
      const seq = parseInt(match[1], 10);
      if (seq > maxSeq) {
        maxSeq = seq;
      }
    }
  }

  return maxSeq + 1;
}

/**
 * Format a sequence number with zero-padding (at least 2 digits).
 */
function formatSequence(seq: number): string {
  return seq.toString().padStart(2, "0");
}

/**
 * Choose a Markdown fence delimiter that does not occur in the payload.
 * Falls back to JSON string content if no safe fence is found.
 */
function chooseFenceDelimiter(payload: string): string | null {
  const candidates = ["```", "````", "`````", "``````"];
  for (const fence of candidates) {
    if (!payload.includes(fence)) {
      return fence;
    }
  }
  return null;
}

/**
 * Render the brief Markdown content.
 */
function renderBriefMarkdown(opts: {
  callID: string;
  sessionID: string;
  callerAgent: string;
  targetAgent: string;
  description: string;
  taskId?: string;
  capturedAt: string;
  taskSlug: string;
  directory: string;
  worktree?: string;
  argsSnapshot: Record<string, unknown>;
  prompt: string;
}): string {
  const lines: string[] = [
    "# Delegation Brief (captured)",
    "",
    `- **callID**: ${opts.callID}`,
    `- **sessionID**: ${opts.sessionID}`,
    `- **caller_agent**: ${opts.callerAgent}`,
    `- **target_agent**: ${opts.targetAgent}`,
    `- **description**: ${opts.description || "(empty)"}`,
  ];

  if (opts.taskId) {
    lines.push(`- **task_id**: ${opts.taskId}`);
  }

  lines.push(
    `- **captured_at**: ${opts.capturedAt}`,
    `- **task_slug**: ${opts.taskSlug}`,
    `- **directory**: ${opts.directory}`,
  );

  if (opts.worktree) {
    lines.push(`- **worktree**: ${opts.worktree}`);
  }

  lines.push(
    "",
    "## Args snapshot (JSON)",
    "",
    "```json",
    JSON.stringify(opts.argsSnapshot, null, 2),
    "```",
    "",
    "## Prompt",
    "",
  );

  const fence = chooseFenceDelimiter(opts.prompt);
  if (fence) {
    lines.push(fence, opts.prompt, fence);
  } else {
    // Fall back to JSON string content
    lines.push(
      "```json",
      JSON.stringify({ prompt: opts.prompt }, null, 2),
      "```",
    );
  }

  return lines.join("\n");
}

/**
 * Render the report Markdown content.
 */
function renderReportMarkdown(opts: {
  callID: string;
  sessionID: string;
  targetAgent: string;
  taskId?: string;
  sequence: number;
  completedAt: string;
  briefPath: string;
  title: string;
  output: string;
  metadata: unknown;
}): string {
  const lines: string[] = [
    "# Completion Report (captured)",
    "",
    `- **callID**: ${opts.callID}`,
    `- **sessionID**: ${opts.sessionID}`,
    `- **target_agent**: ${opts.targetAgent}`,
  ];

  if (opts.taskId) {
    lines.push(`- **task_id**: ${opts.taskId}`);
  }

  lines.push(
    `- **sequence**: ${formatSequence(opts.sequence)}`,
    `- **completed_at**: ${opts.completedAt}`,
    `- **brief**: ${opts.briefPath}`,
    "",
    "## Title",
    "",
    opts.title,
    "",
    "## Output",
    "",
  );

  const fence = chooseFenceDelimiter(opts.output);
  if (fence) {
    lines.push(fence, opts.output, fence);
  } else {
    lines.push(
      "```json",
      JSON.stringify({ output: opts.output }, null, 2),
      "```",
    );
  }

  lines.push(
    "",
    "## Metadata (JSON)",
    "",
    "```json",
    JSON.stringify(opts.metadata, null, 2),
    "```",
  );

  return lines.join("\n");
}

/**
 * Safe logging wrapper. Never throws.
 */
function safeLog(
  client: PluginContext["client"],
  level: "info" | "warn" | "error",
  message: string,
  extra?: Record<string, unknown>,
): void {
  try {
    client.app.log({
      body: {
        service: SERVICE,
        level,
        message,
        extra,
      },
    });
  } catch {
    // Logging failure is silent; we cannot block the tool call
  }
}

// ============================================================================
// Plugin implementation
// ============================================================================

export const HandoffAuditLog: PluginFactory = async (ctx: PluginContext) => {
  const { client, directory, worktree } = ctx;

  // In-memory state
  const pendingBefore = new Map<string, BeforeRecord>();
  const sessionAgentCache = new Map<string, string>();
  const sequenceLocks = new Map<string, Promise<number>>();

  /**
   * Allocate a sequence number with in-process async mutex per handoff dir.
   */
  async function allocateSequenceAsync(handoffDir: string): Promise<number> {
    const existing = sequenceLocks.get(handoffDir);
    if (existing) {
      await existing;
    }

    const allocate = (async () => {
      return allocateSequence(handoffDir);
    })();

    sequenceLocks.set(handoffDir, allocate);
    const seq = await allocate;
    sequenceLocks.delete(handoffDir);
    return seq;
  }

  return {
    // Cache sessionID -> agent from chat/message hook
    async "chat.message"(input, _output) {
      try {
        if (input.agent && input.sessionID) {
          sessionAgentCache.set(input.sessionID, input.agent);
        }
      } catch (err) {
        safeLog(client, "warn", "chat.message hook failed", {
          error: err instanceof Error ? err.message : String(err),
        });
      }
    },

      // Capture brief before task execution
      async "tool.execute.before"(input, output) {
        try {
          if (input.tool !== "task") {
            return;
          }

          const args = (output.args || {}) as TaskArgs;
          const callID = input.callID;
          const sessionID = input.sessionID;

          // Clone args without mutating output.args
          const argsSnapshot: Record<string, unknown> = {};
          for (const [k, v] of Object.entries(args)) {
            if (k !== "prompt") {
              argsSnapshot[k] = v;
            }
          }

          // Resolve task slug and handoff directory
          const taskSlug = inferTaskSlug({
            directory,
            worktree,
            sessionID,
          });
          const scratchRoot = resolveScratchRoot({ directory, worktree });
          const handoffDir = join(scratchRoot, taskSlug, "handoffs");

          // Ensure directory exists
          if (!existsSync(handoffDir)) {
            mkdirSync(handoffDir, { recursive: true });
          }

          // Allocate sequence
          const sequence = await allocateSequenceAsync(handoffDir);
          const seqStr = formatSequence(sequence);

          // Resolve agent names
          const targetAgent = sanitizeFilename(args.subagent_type || "unknown-agent");
          const callerAgent = sessionAgentCache.get(sessionID) || "unknown";

          // Build file paths
          const briefPath = join(handoffDir, `${seqStr}-brief-${targetAgent}.md`);
          const reportPath = join(handoffDir, `${seqStr}-report-${targetAgent}.md`);

          // Check for collision
          let actualBriefPath = briefPath;
          let actualReportPath = reportPath;
          if (existsSync(briefPath)) {
            const shortCallID = callID.slice(0, 8);
            safeLog(client, "warn", "Brief file collision detected", {
              briefPath,
              callID,
              shortCallID,
            });
            // Allocate a duplicate suffix
            actualBriefPath = join(
              handoffDir,
              `${seqStr}-brief-${targetAgent}-duplicate-${shortCallID}.md`,
            );
            actualReportPath = join(
              handoffDir,
              `${seqStr}-report-${targetAgent}-duplicate-${shortCallID}.md`,
            );
          }

          pendingBefore.set(callID, {
            sequence,
            agent: callerAgent,
            briefPath: actualBriefPath,
            reportPath: actualReportPath,
            beforeTimestamp: new Date().toISOString(),
            argsSnapshot,
          });

          // Render and write brief
          const briefContent = renderBriefMarkdown({
            callID,
            sessionID,
            callerAgent,
            targetAgent: args.subagent_type || "unknown-agent",
            description: args.description || "",
            taskId: args.task_id,
            capturedAt: new Date().toISOString(),
            taskSlug,
            directory,
            worktree,
            argsSnapshot,
            prompt: args.prompt || "",
          });

          writeFileSync(actualBriefPath, briefContent, "utf-8");
          safeLog(client, "info", "Brief captured", {
            callID,
            briefPath: actualBriefPath,
            sequence,
          });
        } catch (err) {
          safeLog(client, "error", "tool.execute.before hook failed", {
            error: err instanceof Error ? err.message : String(err),
            callID: input.callID,
            tool: input.tool,
          });
        }
      },

      // Capture report after task execution
      async "tool.execute.after"(input, output) {
        try {
          if (input.tool !== "task") {
            return;
          }

          const callID = input.callID;
          const sessionID = input.sessionID;
          const args = (input.args || {}) as TaskArgs;

          // Look up pending before record
          const before = pendingBefore.get(callID);

          let sequence: number;
          let briefPath: string;
          let targetAgent: string;
          let taskId: string | undefined;

          if (before) {
            sequence = before.sequence;
            briefPath = before.briefPath;
            targetAgent = sanitizeFilename(args.subagent_type || "unknown-agent");
            taskId = args.task_id;
            pendingBefore.delete(callID);
          } else {
            // Before record missing; allocate a new sequence
            safeLog(client, "warn", "Before record missing for task call", {
              callID,
              sessionID,
            });

            const taskSlug = inferTaskSlug({
              directory,
              worktree,
              sessionID,
            });
            const scratchRoot = resolveScratchRoot({ directory, worktree });
            const handoffDir = join(scratchRoot, taskSlug, "handoffs");

            if (!existsSync(handoffDir)) {
              mkdirSync(handoffDir, { recursive: true });
            }

            sequence = await allocateSequenceAsync(handoffDir);
            targetAgent = sanitizeFilename(args.subagent_type || "unknown-agent");
            briefPath = "(not captured)";
            taskId = args.task_id;
          }

          const seqStr = formatSequence(sequence);
          const reportPath = before
            ? before.reportPath
            : join(
                resolveScratchRoot({ directory, worktree }),
                inferTaskSlug({ directory, worktree, sessionID }),
                "handoffs",
                `${seqStr}-report-${targetAgent}.md`,
              );

          // Render and write report
          const reportContent = renderReportMarkdown({
            callID,
            sessionID,
            targetAgent: args.subagent_type || "unknown-agent",
            taskId,
            sequence,
            completedAt: new Date().toISOString(),
            briefPath,
            title: output.title || "",
            output: output.output || "",
            metadata: output.metadata || {},
          });

          // Check for report collision before writing
          let actualReportPath = reportPath;
          if (existsSync(reportPath)) {
            const shortCallID = callID.slice(0, 8);
            safeLog(client, "warn", "Report file collision detected", {
              reportPath,
              callID,
              shortCallID,
            });
            actualReportPath = join(
              resolveScratchRoot({ directory, worktree }),
              inferTaskSlug({ directory, worktree, sessionID }),
              "handoffs",
              `${seqStr}-report-${targetAgent}-duplicate-${shortCallID}.md`,
            );
          }

          writeFileSync(actualReportPath, reportContent, "utf-8");
          safeLog(client, "info", "Report captured", {
            callID,
            reportPath: actualReportPath,
            sequence,
          });
        } catch (err) {
          safeLog(client, "error", "tool.execute.after hook failed", {
            error: err instanceof Error ? err.message : String(err),
            callID: input.callID,
            tool: input.tool,
          });
        }
      },
  };
};
