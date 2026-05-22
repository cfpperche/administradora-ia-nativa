---
paths:
  - ".claude/hooks/rule-load-debug.sh"
  - ".claude/tools/probe.sh"
  - ".claude/.rule-load-debug.jsonl"
---

# Rule load debug

Opt-in observability for the native `InstructionsLoaded` hook event. Logs every CLAUDE.md / `.claude/rules/*.md` load to a JSONL audit file so the agent (and the human) can verify that path-scoped rules are firing on the correct triggers, debug "rule didn't load when expected" symptoms, and confirm startup-context shape after frontmatter changes. Pure observability — no decision control, no blocks, no advisories (the harness itself ignores `InstructionsLoaded` stdout/stderr per docs).

## What fires

`InstructionsLoaded` is documented by CC as firing on every instruction-file load — at session start for eager files (CLAUDE.md, unconditional rules), lazily on file-access for path-scoped rules, and again after `/compact` (`load_reason: "compact"`). The payload carries:

- `file_path` — absolute path of the loaded file
- `memory_type` — `"User" | "Project" | "Local" | "Managed"`
- `load_reason` — `"session_start" | "nested_traversal" | "path_glob_match" | "include" | "compact"`
- `globs` — array, present only on `path_glob_match`
- `trigger_file_path` — the file whose access triggered the lazy load
- `parent_file_path` — the importing file, for `include` loads
- `session_id`, `transcript_path`, `cwd`, `hook_event_name`

The hook script lives at `.claude/hooks/rule-load-debug.sh`, is registered under `InstructionsLoaded` in `.claude/settings.json` with no matcher (catches all reasons). The script self-gates: silent exit 0 unless `CLAUDE_RULE_LOAD_DEBUG=1` is set. Same opt-in posture as `CLAUDE_RUNTIME_INTROSPECT_DEBUG` and `CLAUDE_SECRETS_ADVISE_ON_EDIT` — capacity is hot only when explicitly turned on, zero per-load overhead otherwise.

## Audit log

`.claude/.rule-load-debug.jsonl`, gitignored, append-only, `flock`-atomic. One JSONL row per load event when enabled. Row shape:

```json
{
  "ts": "2026-05-13T14:22:18Z",
  "session_id": "abc123",
  "file": ".claude/rules/secrets-scan.md",
  "memory_type": "Project",
  "load_reason": "path_glob_match",
  "globs": [".claude/hooks/secrets-*.sh", ".githooks/**", "..."],
  "trigger_file": ".claude/hooks/secrets-scan.sh",
  "parent_file": null
}
```

Paths in `file` and `trigger_file` are relativized against `$CLAUDE_PROJECT_DIR` for readability. Absolute paths in the original `InstructionsLoaded` payload are preserved only when relativization fails (e.g. file outside project root).

## Probe

`bash .claude/tools/probe.sh rule-loads` — reads the JSONL, emits a human-readable table of the last 20 events:

```
2026-05-13T14:22:18Z  path_glob_match     .claude/rules/secrets-scan.md  ← .claude/hooks/secrets-scan.sh
2026-05-13T14:22:18Z  session_start       .claude/rules/delegation.md
2026-05-13T14:22:18Z  session_start       CLAUDE.md
```

Flags:

- `--json` — emit the raw JSONL (post-filter), one row per line. For agent consumption / `jq` chaining.
- `--session <id>` — filter to a single `session_id`.
- `--reason <r>` — filter to a single `load_reason` (e.g. `path_glob_match`).

Missing log file → `status: no-snapshot` with hint to set `CLAUDE_RULE_LOAD_DEBUG=1`. Missing `jq` → graceful skip. Both fail-open — debug tooling must never block real work.

## Use cases

1. **Verify path-scoping after a frontmatter edit.** Enable, restart session, `/memory` shows reduced rule list. Touch a file matching one of the new globs (e.g. `Read .claude/hooks/secrets-scan.sh`). Inspect the log: the matching rule should appear with `load_reason: "path_glob_match"`, the correct glob list, and the triggering file recorded. If it doesn't fire, the glob is wrong.
2. **Debug "rule didn't apply when I expected".** When agent behavior suggests a rule wasn't in context, check `--session <id> --reason path_glob_match` to confirm whether the rule actually loaded.
3. **Measure startup load.** `--reason session_start` shows the unconditional set. Compare against expectations.
4. **Audit compaction behavior.** `--reason compact` shows which files survived the re-load step. Documented separately (`.claude/rules/compaction-continuity.md`).

## Escape hatch

`CLAUDE_RULE_LOAD_DEBUG` unset or `0` → hook exits silently with no IO. No `OFF` variant needed — absence IS the off state. Delete the JSONL when it grows tiresome; the hook recreates it on next event.

## Gotchas

- **Hook fires asynchronously per CC docs** — `InstructionsLoaded` is non-blocking, runs in parallel with whatever triggered the load. Cannot influence loading, only observe. Don't try to "filter" or "redact" rule loads here; use frontmatter `paths:` or the `claudeMdExcludes` setting instead.
- **No decision control by design.** Exit code is ignored, stdout is ignored. Don't shape this hook into something that tries to communicate back to the agent — there is no return channel. The audit log + probe is the only signal path.
- **Logs are NOT shipped to forks via sync-harness.** The hook script + this rule doc + the settings.json registration ride along (manifest-tracked), but the JSONL log lives at `.claude/.rule-load-debug.jsonl` (gitignored, machine-local). Each fork accumulates its own debug log when enabled.
- **`session_id` is the same across `/compact` and `/resume`** — see `.claude/rules/session-handoff.md` § "Parallel sessions and other start triggers". A log filtered by `--session <id>` therefore includes pre-compact and post-compact loads in one slice; the `load_reason` field discriminates (`session_start` vs `compact`).
- **`InstructionsLoaded` may not exist on older CC builds.** The event is documented at `code.claude.com/docs/en/hooks#instructionsloaded`. If a fork's CC version pre-dates the event, the hook registration is silently inert (unknown events are simply not dispatched). No fallback; opt-in env-var stays off and observability returns no signal.
- **Don't conflate with `.claude/memory/`.** The auto-memory bucket (`~/.claude/projects/<path>/memory/`) is a different mechanism entirely — Claude writes notes there, separate from rule loading. This capacity ONLY observes the InstructionsLoaded event on CLAUDE.md and `.claude/rules/*.md` files.
- **Intra-session dedup is per-rule, not per-glob (2026-05-13 dogfood).** Once a path-scoped rule loads in a session via any matching glob, subsequent reads/edits of any file matching ANY of that rule's globs produce NO new `InstructionsLoaded` event. The dedup is scoped to the rule — CC tracks "rule X has been loaded this session" and skips re-emission regardless of which glob the new trigger matched. Implication for validation: a trigger→rule mapping table is only fully exercisable in a fresh session per trigger. "Edit `package.json` to verify `supply-chain.md` loads" only fires the audit row if `supply-chain.md` hasn't already loaded earlier this session (via reading e.g. `.claude/hooks/supply-chain-scan.sh`).
