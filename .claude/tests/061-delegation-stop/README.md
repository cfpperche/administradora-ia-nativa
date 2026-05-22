# 061-delegation-stop tests

Scenario coverage for `.claude/hooks/delegation-stop.sh` — the `SubagentStop`
hook that closes the delegation audit row opened by `delegation-gate.sh` at
`PreToolUse(Agent)` time. See `docs/specs/061-subagent-stop-hook/`.

Run: `bash run-all.sh` (quiet) or `bash run-all.sh -v` (verbose).

Each script builds an isolated `mktemp` project dir, seeds a synthetic
`delegation-audit.jsonl` + per-sub-agent transcript (and `.meta.json` sidecar
where relevant), pipes a `SubagentStop` payload to the hook with
`CLAUDE_PROJECT_DIR` pointed at the tmp dir, and asserts the appended close
row via `jq`. Payloads are generated inline rather than from a static
`fixtures/` dir because the payload's `agent_transcript_path` must reference a
real file inside the per-run tmp dir.

| Script | Scenario |
| --- | --- |
| `01-normal-completion.sh` | normal stop → `exit=ok`, `edit_count=0`, `correlation=tool_use_id`, numeric `duration_ms` |
| `02-edit-count.sh` | transcript with 3 Edit + 1 Write → `edit_count=4` (Read/Bash excluded) |
| `03-loop-budget.sh` | `consecutive_failures` ≥ budget → `exit=loop-budget-exceeded` |
| `04-orphan-stop.sh` | no matching dispatch row → `correlation=unmatched`, `duration_ms=null` |
| `05-malformed-payload.sh` | empty stdin + missing `agent_id` → exit 0, no row |
| `06-missing-sidecar.sh` | no `.meta.json` → `tool_use_id=null`, `correlation=heuristic-session-type` |
| `07-unwritable-log.sh` | write-stripped audit log → fail-open exit 0, no row (skipped as root) |
| `08-shellcheck.sh` | `delegation-stop.sh` + `delegation-gate.sh` lint clean (`bash -n` fallback) |
| `09-settings-registration.sh` | `settings.json` valid JSON + `SubagentStop` registered |
