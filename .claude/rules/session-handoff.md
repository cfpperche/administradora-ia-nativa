---
paths:
  - ".claude/SESSION.md"
  - ".claude/hooks/session-start.sh"
  - ".claude/hooks/session-stop.sh"
  - ".claude/.session-state/**"
---

# Session handoff

`.claude/SESSION.md` is the working handoff between Claude Code sessions. The harness enforces it via hooks in `.claude/settings.json`:

- **`SessionStart` hook** (`.claude/hooks/session-start.sh`) injects the current `SESSION.md` into context — so prior context is always present without anyone reading it manually.
- **`Stop` hook** (`.claude/hooks/session-stop.sh`) blocks once per session if the repo has uncommitted changes but `SESSION.md` was not updated. The block injects a reminder; you write the update and end the turn normally. Blocks at most once per session — no infinite loops.

## What to write in SESSION.md

Update before ending a session that touched the repo. Suggested sections (free-form prose, all optional):

- **Current state** — what's working, what's broken, what's in flight
- **WIP** — code/changes left mid-stream that need finishing next time
- **Next steps** — concrete tasks for the next session
- **Decisions & gotchas** — non-obvious choices made, traps discovered, things future-you would want to know

Keep it short and scan-able. The goal is a brief for the next session, not a journal. Replace stale content rather than appending — `git log` is the audit trail.

## What NOT to put here

- Code snippets that belong in actual source files
- Long narratives — keep entries terse
- Anything already captured in commit messages or CLAUDE.md
- A "cumulative" anything — gotchas / decisions / lessons that accumulate across sessions are not what SESSION.md is for. Migrate them to `.claude/memory/<topic>.md` (project knowledge) or `~/.claude/projects/<path>/memory/feedback_<topic>.md` (behavioural feedback), then drop from SESSION.md. The pointer in the index is the handoff; the body lives in the memory file.

## Size discipline

**Target: SESSION.md ≤ 4 KB.** The SessionStart hook serves the file verbatim via `cat`; the Claude Code harness truncates injected hook outputs past roughly 2-3 KB into a preview + a sidecar persisted-output file. When SESSION.md grows past the cap, the next session's agent receives a partial preview — the immediate "next step" may live past the cutoff and get silently dropped from the handoff context.

The cap is enforced behaviourally at session-end, not by tooling. **Prune before write** when closing a session:

1. **Migrate durable entries out.** Anything that survives this session as "future-me will want to know this" belongs in a memory file, not SESSION.md. Project-factual knowledge (capacity quirks, prior decisions and their reasoning, platform constraints discovered through dogfooding) goes to `.claude/memory/<topic>.md`. Behavioural guidance ("when X, do Y") goes to `~/.claude/projects/<path>/memory/feedback_<topic>.md`. The SESSION.md entry then becomes a `[[memory-slug]]` pointer at most.
2. **Drop entries already in commit messages or specs.** `git log --oneline` + `docs/specs/NNN-*/` are the audit trail. Repeating their contents in SESSION.md is the journaling anti-pattern.
3. **Replace, don't append.** The previous session's "Next steps" gets replaced by this session's, never doubled. The previous session's "Current state" is overwritten, not extended. A second `## Next steps` block or a `(cumulative)` suffix on a section header is the signal that pruning was skipped.
4. **Carryover stays a parking lot.** Items in `## Carryover` that got resolved during the session drop out at session-end — they don't earn a "✓ done" badge, they just disappear.

If at session-end the file is past 4 KB, the prune was insufficient — make another pass. The Stop hook does NOT enforce the size cap today (deliberate: behavioural discipline first, automation second — promote to a hook check if the discipline empirically fails).

## Reader-side defence — Read the source when injected output is truncated

Defense in depth, paired with the size discipline above. When the Claude Code harness truncates a large hook output, it preserves the full output to a sidecar file and shows only a preview in the agent's context. **The agent must scan for truncation markers and Read the source file before answering anything that depends on the injected block** — otherwise key information past the preview cutoff is silently lost.

### Markers to scan for

Telltale signs that an injected block is partial, not the full content:

- `Output too large (N KB).` literal
- `Full output saved to: <path>` literal
- `<persisted-output>` opening tag
- `Preview (first N KB):` literal
- A block that ends with `...` and no closing delimiter
- A `=== <SOURCE> ===` block that opens but never closes with `=== end <SOURCE> ===`

Any one of those = partial content. The persisted-output path (when shown) is the full content; the SOURCE file referenced by the hook is the canonical content.

### What to do

Before responding to anything that touched the truncated block:

1. **Identify the source file** the hook was meant to inject — e.g., `.claude/SESSION.md`, `.claude/COMPACT_NOTES.md`, `.claude/REMINDERS.md`.
2. **Read it directly** via the Read tool, full file.
3. **Then answer.** Reasoning from the partial preview is the failure mode this rule exists to prevent.

If multiple injected blocks are truncated, Read each source file. Truncation is silent past the marker — the harness does not warn beyond the literal, so the agent must catch it.

### Why this matters

The failure mode it prevents (canonical example, 2026-05-15 in this very project): SessionStart resume hook injected SESSION.md but the file had grown to 12 KB, exceeded the harness's ~2 KB preview cap, and the truncation marker was clearly visible — but the agent processed the 2 KB preview as if it were the whole file, summarised it for the user, and missed the immediate "next step" (which lived past the cutoff). The user had to ask why the next step was missing. The injected block had ALL the information needed to know it was partial: `Output too large (12KB). Full output saved to: …`. Reading the source file would have caught it.

This is a behavioural failure, not a tooling failure — even when the size discipline of the source file is improved (see § Size discipline above), the agent must still defend against future growth. Both defences are required: size discipline on the writer side (here) AND truncation-marker scanning on the reader side (here). One alone is fragile.

## Escape hatch

Set `CLAUDE_SKIP_SESSION_HOOKS=1` in the environment to disable Stop-hook enforcement (e.g., for quick Q&A sessions where no commit is intended). The SessionStart injection still runs.

## State files

`.claude/.session-state/<session_id>/` holds four ephemeral artifacts per Claude Code session: `started-at` (touched by `SessionStart`), `nagged` (touched by `Stop` when it blocks), `start-porcelain.txt` (a snapshot of `git status --porcelain` captured by `SessionStart`), and `edited-files.txt` (per-session list of Edit/Write/MultiEdit `file_path`s, append-only with dedup, populated by the `session-track-edits.sh` `PostToolUse` hook; the file is also seeded as empty by `SessionStart` so its mere presence is the "tracker-enabled" marker). Gitignored — do not commit. The per-`session_id` subdir layout isolates parallel sessions; before it landed, both markers lived directly under `.claude/.session-state/` and any SessionStart fire from any session would `rm -f` the shared `nagged` marker, leading to spurious re-blocks of unrelated sessions.

`session_id` comes from the stdin payload Claude Code passes to every hook (`$.session_id`). When absent (older payload shapes, future variants, manual fixtures), or when it contains characters outside `^[a-zA-Z0-9_-]+$`, both hooks fall to the literal subdir `unknown` — predictable degradation, no path traversal possible.

`SessionStart` also runs a best-effort cleanup at the end: `find .claude/.session-state -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} +`. Crashed sessions leave orphan subdirs; this sweep removes them within a week without manual intervention. Cleanup failures are silenced — never block the hook. The porcelain snapshot rides inside the same subdir, so the 7-day sweep removes it atomically with the rest of the state — no separate TTL.

### Edit attribution (primary signal)

The porcelain-compare answers "did the worktree change during this session?" — observation of the tree, not attribution to the session. The signal misfires for **bystander sessions** (research-only, read-only Bash) when a sibling Claude Code session or an out-of-band process modifies the tree during the bystander's lifetime: porcelain at Stop differs from `start-porcelain.txt` and the bystander gets nagged for someone else's edits. The canonical example, 2026-05-16 in this very project: a research-only session sat from 13:23 to 13:27 doing zero Edit/Write tool calls; a sibling session modified step-09 templates at 13:26/13:27; the research session's Stop fired the nag at 13:27:48 even though the transcript shows no edits.

The edit attribution fix uses **per-session edit attribution**. A `PostToolUse(Edit|Write|MultiEdit)` hook (`.claude/hooks/session-track-edits.sh`) appends each tool-call's `file_path` (project-relative, deduped) to `<state-dir>/edited-files.txt`. `SessionStart` seeds the file as empty at session boundary so its **presence** means "tracker is installed and active for this session" and its **emptiness** means "the tracker fired zero times". Stop reads it as the primary signal:

- **File present, empty** → session edited nothing the tracker could see → `exit 0` silently. Bystander or Bash-only-edit case (see § Trade below).
- **File present, non-empty, every listed path is clean in `git status --porcelain`** (committed or reverted) → `exit 0` silently.
- **File present, non-empty, at least one listed path still dirty** → fall through to the block-unless-SESSION-updated path. The porcelain-compare is skipped on this branch — the tracker has already decided we have own WIP, re-running the compare would be redundant.
- **File absent** → legacy session (started before the tracker deployed, or SessionStart somehow skipped) → fall through to the porcelain-compare path unchanged.

**Trade**: file-present-and-empty collapses two real-world classes — pure bystander AND Bash-only-edit sessions — into the same silent-pass branch. Sessions that edit exclusively via `sed -i`, `cat > file`, IDE saves, or external scripts produce no tracker entries, and Stop will not nag even if SESSION.md is stale. Accepted because the bystander quiet was the primary goal, the dominant agent edit path is Edit/Write/MultiEdit which IS tracked, and Bash-argument parsing for path attribution is fragile. Users who rely on Bash-driven edits must remember to update SESSION.md themselves.

### Carryover discrimination (fallback)

Previously the Stop hook treated `git status --porcelain` returning non-empty as "this session has WIP that needs a SESSION.md handoff" — but the signal conflates three cases: real WIP, pre-existing carryover from prior sessions (already documented), and pure no-op sessions (greeting / Q&A / read-only Bash). The carryover-discrimination fix closes the false-positive on cases (2)/(3): SessionStart writes `start-porcelain.txt` (best-effort — guarded by `git rev-parse --git-dir` plus `|| true` on the redirect; absent if git is unavailable or the filesystem is read-only); Stop compares the current porcelain against the snapshot via bash string equality before applying the SESSION.md mtime check. Byte-identical → nothing changed this session → exit 0 silently. Different → fall through to today's block-unless-SESSION-updated path.

The porcelain-compare mechanism remains **shipped**, not superseded — it is still load-bearing on the legacy-session branch above. The primary path (edit attribution) handles modern sessions; the porcelain-compare handles every session that started before the tracker deployed plus any session where `SessionStart` couldn't seed `edited-files.txt` (read-only fs, etc).

Missing snapshot (older session that started before 023 landed, or git/fs failure at SessionStart) is the safe-fallback case: Stop skips the comparison and the original mtime-only logic runs. Same conservative posture as the rest of the session-state machinery.

`/compact` and `/resume` both fire `SessionStart` with the same `session_id`, so the snapshot is **overwritten** at compaction-resume time — the porcelain at that moment becomes the new baseline. Correct: pre-compact work should already be committed or noted in SESSION.md by then. `CLAUDE_SKIP_SESSION_HOOKS=1` short-circuits both hooks; no snapshot is written; the next session without the env var sees no snapshot → fallback.

## Parallel sessions and other start triggers

The "block at most once per session" guarantee is keyed on `session_id`. `session_id` persists through:

- **`/compact` (manual or auto-compact in 1M-context Opus)** — `source=compact` SessionStart fires, but the `session_id` is identical. So `<id>/nagged` survives the compaction; the agent isn't re-blocked unless `SESSION.md` becomes stale again relative to the touched `<id>/started-at`.
- **`/resume` of a paused conversation** — `source=resume`, same `session_id`, same nag state preserved.
- **Multiple concurrent Claude Code sessions in the same project** — each gets its own `session_id` and its own subdir. Session A's nag is never reset by Session B's SessionStart.

`session_id` is regenerated (fresh UUID) only on `source=startup` (new conversation) and after `/clear` (lifecycle reset). Those are the right moments for a fresh nag cycle.

## Parallel WIP coordination

When you intentionally open a second Claude Code session on the same project to work in parallel (e.g. spec curation in one session while another runs dogfood passes), use a `## Parallel WIP` block in `SESSION.md` to signal what each session owns. The block is the lightest possible coordination layer: zero new tooling, zero hooks, zero state files. SESSION.md is already auto-injected at SessionStart of every new session, so the signal reaches the next agent for free.

Shape:

```markdown
## Parallel WIP

- session opened 2026-05-12 11:00 — curating browser-auth-workflow
  (touching `.claude/rules/mcp-recipes.md`, `.claude/rules/secrets-scan.md`).
  Other sessions: defer these paths until this block is removed.
```

Conventions:

- **One bullet per active parallel session.** ISO date + short intent + path list + clear "defer" instruction.
- **The session opening parallel work writes the bullet.** Then commits SESSION.md immediately so the change is visible to the next session that starts. If the opener forgets, the user can do it themselves — same shape.
- **The session removes its bullet when work is committed and merged.** The bullet is a live claim, not a journal. Stale bullets are noise.
- **The block disappears entirely when no parallel work is in flight.** Don't keep an empty `## Parallel WIP` section as scaffolding.
- **Other sessions read SESSION.md (always auto-injected) and respect the block.** If you must edit a deferred path anyway (e.g. fixing a typo unrelated to the spec), say so in your commit message so the parallel-session owner can reconcile on merge.

When the convention is enough vs when it isn't:

- Two concurrent sessions, each on a different spec / different file area → convention covers it.
- Two concurrent sessions racing on the SAME file → convention is advisory; coordinate via the user or pause one session.
- More than two concurrent sessions → still works but the bullet count grows; if this becomes routine, that's the empirical signal to consider richer machinery (a follow-up spec). Don't pre-build.

This is deliberately a behavioural convention rather than a code-enforced one. The per-session state directory isolation gave each session its own state directory; this convention closes the remaining gap (cross-session intent visibility) at zero code cost. If real-world use surfaces collisions the convention can't catch — recurring forgotten bullets, fixed-on-merge surprises, sessions that genuinely need to touch the same paths — that's the trigger to revisit; until then, keep the surface tiny.

## Cross-capacity dependency

`.claude/tools/probe.sh` reads `started-at` as the "session boundary" signal to detect stale snapshots. It does NOT read a specific subdir — instead it scans `.claude/.session-state/*/started-at` and takes the maximum mtime as the conservative boundary. Single-session use: identical behavior to a single-subdir layout. Parallel sessions: `stale=true` may trigger earlier in the older session (a conservative false positive — agent re-runs the verifier, safe direction).
