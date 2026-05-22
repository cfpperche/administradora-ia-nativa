# Compaction continuity

When the Claude Code context window fills up (auto-compact) or the user runs `/compact`, the conversation is summarized and older turns are dropped. The summary preserves the gist but loses raw signal — exact wording of decisions, verbatim user intent, specific paths and identifiers. This project preserves that raw signal across the compaction boundary via two hooks.

## Flow

1. **`PreCompact` hook** (`.claude/hooks/pre-compact.sh`) fires before compaction. It reads the transcript JSONL referenced by `transcript_path`, extracts the **last 12 real user turns** plus the assistant text/tool_use blocks between them, and writes `.claude/COMPACT_NOTES.md`. Drops: tool_result bodies (stale post-compact), assistant thinking blocks (internal). Also snapshots git branch and uncommitted status.

2. **`/compact` runs** — Claude Code's summarizer compresses the transcript. The `## Compact Instructions` section in `CLAUDE.md` steers what the summary retains.

3. **`SessionStart` hook with `source: "compact"`** (`.claude/hooks/session-start.sh`) fires after compaction. It detects the source and injects `COMPACT_NOTES.md` as `additionalContext` — so the post-compact window has both the (lossy) summary *and* the (verbatim) raw signal from the last 12 turns.

## Why these primitives

`PreCompact` cannot inject context — its output is side-effect only. `SessionStart` *can* inject context and re-runs after compaction with `source: "compact"`. So the only viable shape is: PreCompact writes to disk, SessionStart reads from disk. Other hooks (PostToolUse, UserPromptSubmit) get baked into the transcript and replayed stale after compaction — useless for this purpose.

## Why mechanical capture (not semantic)

`/compact` already runs a semantic summarizer. Doing a second semantic pass in PreCompact would be redundant, lossy (each summary discards nuance), and add an API dependency. The hook's job is the *opposite*: preserve exactly the raw material that summarization would otherwise destroy. Verbatim user messages, verbatim assistant text, tool *names* (not outputs) — that's the signal worth carrying.

## Files

- `.claude/hooks/pre-compact.sh` — captures snapshot
- `.claude/hooks/session-start.sh` — injects snapshot when `source=compact`, SESSION.md otherwise
- `.claude/COMPACT_NOTES.md` — the snapshot itself (gitignored, ephemeral, overwritten each compaction)
- `CLAUDE.md` § *Compact Instructions* — steers the summarizer

## Gotchas

- Hooks only register on the **next** session — `settings.json` changes mid-session don't retro-activate.
- The snapshot file is **overwritten** each compaction, not appended. Multiple compactions in one session lose the earliest snapshot.
- "Last 12 turns" counts real user prompts only (string `content`), not tool_result entries.
- If `jq` is missing or the transcript can't be read, PreCompact silently exits — compaction proceeds without a snapshot. Better degraded than blocking.
- `CLAUDE_SKIP_SESSION_HOOKS=1` does **not** disable PreCompact (only the Stop nag). Compaction snapshotting always runs when registered.
