---
name: skill
description: Skill compliance toolkit. Use when scaffolding a new Agent0 skill, auditing existing skills against the agentskills.io specification, porting non-compliant SKILL.md frontmatter to compliance, validating a single SKILL.md, or listing all skills with their declared portability tier. Subcommands - new <slug> [--tier cc-native|agentskills-portable|runtime-agnostic], audit [<slug>|--all], port <slug>, validate <slug>, list. See `.claude/skills/skill/references/spec-snapshot.md` for the frozen spec and `.claude/skills/skill/references/portability-tiers.md` for the 3-tier definition.
license: MIT
compatibility: Designed for Claude Code. Body references `.claude/skills/` paths and bash scripts at `.claude/skills/skill/scripts/`; portable to any runtime that maps a `.claude/`-analog directory and runs bash 4+.
metadata:
  agent0-portability-tier: cc-native
  version: "0.1"
argument-hint: <new <slug> [--tier <tier>] | audit [<slug>|--all] | port <slug> | validate <slug> | list>
---

# /skill — skill compliance toolkit

Scaffolds new Agent0 skills, audits existing ones against the agentskills.io specification, ports non-compliant SKILL.md frontmatter to compliance, and validates individual SKILL.md files. Every Agent0 skill should pass `/skill validate <slug>` before being committed.

See spec `docs/specs/033-skill-compliance-toolkit/` for the rationale; `references/spec-snapshot.md` for the frozen agentskills.io rules; `references/portability-tiers.md` for the 3-tier classification (`cc-native` / `agentskills-portable` / `runtime-agnostic`).

## Argument parsing

User invokes as `/skill <subcommand> [args]`. The raw argument string is `$ARGUMENTS`. Parse it yourself: split on whitespace, first token is the subcommand (`new` / `audit` / `port` / `validate` / `list`); the rest are subcommand args. Do not rely on `$1`/`$2` positional substitution — harness behavior differs between slash invocation and Skill tool invocation. Always parse `$ARGUMENTS`.

Raw invocation: `$ARGUMENTS`

State paths used throughout:
- Skill root: `.claude/skills/<slug>/` (resolved relative to `$CLAUDE_PROJECT_DIR` or repo root)
- Toolkit root: `${CLAUDE_SKILL_DIR}` (when invoked as `/skill`, this resolves to `.claude/skills/skill/`)
- Validator: `${CLAUDE_SKILL_DIR}/scripts/validate.sh`
- Porter: `${CLAUDE_SKILL_DIR}/scripts/port-frontmatter.sh`
- Templates: `${CLAUDE_SKILL_DIR}/templates/{SKILL.md,cc-native,portable}.tmpl`

## Subcommand: `new <slug> [--tier <tier>]`

Scaffold a new Agent0 skill with a spec-compliant SKILL.md. Parse `$ARGUMENTS`: first token must be `new`; second token is the slug; optional `--tier <tier>` selects the template variant (default `cc-native`).

1. **Validate the slug**:
   - Reject if missing, empty, or non-kebab-case (`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`).
   - Reject if `.claude/skills/<slug>/` already exists.

2. **Select the template**:
   - `--tier cc-native` (default) → `templates/cc-native.tmpl`
   - `--tier agentskills-portable` → `templates/portable.tmpl`
   - `--tier runtime-agnostic` → `templates/portable.tmpl` (no separate template in v1; switch the `metadata.agent0-portability-tier` value to `runtime-agnostic` post-substitution and remind the user to verify OS-agnostic patterns in the body)
   - Any other value → refuse with the canonical list.

3. **Scaffold the directory and copy the template**:
   ```bash
   mkdir -p .claude/skills/<slug>
   cp ${CLAUDE_SKILL_DIR}/templates/<selected>.tmpl .claude/skills/<slug>/SKILL.md
   ```

4. **Substitute placeholders** in the new SKILL.md (literal replace):
   - `{{SLUG}}` → `<slug>`
   - `{{DATE}}` → current date in `YYYY-MM-DD` (UTC)
   - Other `{{...}}` placeholders (description, title, opening, subcommands) are left for the user to fill — the meta-skill provides structure, not content.

5. **Run validate immediately**:
   ```bash
   bash ${CLAUDE_SKILL_DIR}/scripts/validate.sh .claude/skills/<slug>
   ```
   If non-zero exit, surface stderr and stop with a hint: "scaffolder placeholder values may have been edited; fill `{{DESCRIPTION_PLACEHOLDER}}` and re-run validate".

6. **Report**: output the new SKILL.md path and tell the user to fill the `{{...}}` placeholders (description first — that's the discovery surface) and re-validate when done.

## Subcommand: `audit [<slug>|--all]`

Inspect skills against the spec and report compliance + tier.

**Target selection** (parse `$ARGUMENTS` after `audit`):
- `audit <slug>` → audit only `.claude/skills/<slug>/`
- `audit --all` (default if no arg) → audit every `.claude/skills/*/SKILL.md` found

**For each target**:
1. Run `bash ${CLAUDE_SKILL_DIR}/scripts/validate.sh .claude/skills/<slug>` and capture exit code + stderr.
2. Read frontmatter to extract declared `metadata.agent0-portability-tier` (or `unknown` if not present).
3. Classify:
   - `✓ compliant` — validator exit 0
   - `✗ non-compliant (ruleN-...)` — validator exit non-0, list rule IDs from stderr
4. **Out of scope**: CC-marketplace skills surfaced via the Claude Code harness (e.g., `init`, `review`, `security-review`, `claude-api`, `simplify`, `fewer-permission-prompts`, `loop`, `schedule`, `update-config`, `keybindings-help`) do not have files under `.claude/skills/` in this repo — they are not enumerated. Note this in the report footer for clarity.

**Output shape**:
```
skill              tier                          status
-----              ----                          ------
brainstorm         cc-native                     ✓ compliant
remind             cc-native                     ✓ compliant
sdd                cc-native                     ✓ compliant
skill              cc-native                     ✓ compliant (meta)
<other>            <tier or unknown>             <status>

summary: N compliant, M non-compliant, audited from .claude/skills/
note: external CC-marketplace skills (init, review, ...) are surfaced by
      the CC harness, not by this repo's .claude/skills/; not audited here.
```

If any target is non-compliant, exit the subcommand with a one-line hint pointing at `/skill port <slug>` as the next step.

## Subcommand: `port <slug>`

Apply `port-frontmatter.sh` to bring a skill's frontmatter into spec compliance. Parse `$ARGUMENTS`: first token `port`, second token `<slug>`.

1. **Validate** — refuse if `.claude/skills/<slug>/SKILL.md` doesn't exist.

2. **Confirm with the user** — show what's about to change (a dry-run preview is the right shape but v1 is destructive; warn the user and ask `y/N` before running). Include the detected tier and the planned compatibility text in the prompt.

3. **Run the porter**:
   ```bash
   bash ${CLAUDE_SKILL_DIR}/scripts/port-frontmatter.sh .claude/skills/<slug>
   ```

4. **Validate the result**:
   ```bash
   bash ${CLAUDE_SKILL_DIR}/scripts/validate.sh .claude/skills/<slug>
   ```
   If validate still fails, surface stderr — the porter does NOT auto-fix every rule (e.g., `rule3-name-dirname-mismatch` requires an editorial decision: rename the file or rename the directory). Hand back to the user.

5. **Verify body bytes preserved** (acceptance scenario from spec 033):
   ```bash
   git diff --stat .claude/skills/<slug>/SKILL.md
   ```
   The diff stat should show ONLY frontmatter line additions; if any line below the frontmatter changed, that's a porter bug and must be reported.

6. **Report**: echo the porter's output line (`ported: <path> (tier: <tier>)`) and the validation result. Suggest the user `git diff .claude/skills/<slug>/SKILL.md` to review before committing.

## Subcommand: `validate <slug>`

Wrap `validate.sh` for a single skill. Parse `$ARGUMENTS`: first token `validate`, second token `<slug>` (omit for the meta-skill itself, i.e., `skill`).

1. **Resolve**: `<slug>` → `.claude/skills/<slug>/`. Default to `skill` (self-validation) if no slug given.

2. **Run**:
   ```bash
   bash ${CLAUDE_SKILL_DIR}/scripts/validate.sh .claude/skills/<slug>
   ```

3. **Report**: echo "pass" on exit 0 (and any stderr soft-warnings), or "fail" with the stderr block on exit non-0. Exit code mirrors `validate.sh`.

## Subcommand: `list`

Enumerate every `.claude/skills/*/` directory with its declared tier and a compliance check at a glance.

1. **Scan**: `ls -d .claude/skills/*/` (alphabetical).

2. **For each**: read SKILL.md frontmatter, extract `name` and `metadata.agent0-portability-tier` (or fall back to "(unknown)" if absent), run validator silently to get pass/fail.

3. **Output one line per skill**:
   ```
   <name>             <tier>                        <✓|✗>
   ```

4. **Footer**: short summary line: `N skills, M compliant, K non-compliant`.

## Unknown subcommand

If the first token of `$ARGUMENTS` is missing or not one of `new`, `audit`, `port`, `validate`, `list`, refuse with a single-line usage hint:

```
/skill <new <slug> [--tier <tier>] | audit [<slug>|--all] | port <slug> | validate <slug> | list>
```

## Notes

- **Defer to canonical when available.** `validate.sh` `exec`s `skills-ref validate` when that Python tool is on PATH. The bash rule set is the zero-dep fallback; `skills-ref` is the source of truth. If the two disagree, prefer `skills-ref` and re-snapshot `references/spec-snapshot.md`.
- **Spec drift.** `references/spec-snapshot.md` was retrieved on 2026-05-17. Re-check the live spec (https://agentskills.io/specification) periodically; when it evolves, re-snapshot and audit `scripts/validate.sh` against the diff. A REMINDERS.md item is the natural cadence reminder.
- **Body not validated.** This toolkit checks frontmatter compliance only. Body portability (e.g., declared `agentskills-portable` tier but body uses `${CLAUDE_SKILL_DIR}`) is operator-asserted; a future enhancement could grep for tier-inconsistent signals during `/skill audit`.
- **`argument-hint` stays top-level.** Per Phase C research, Claude Code reads this field only at the top of frontmatter. The porter does NOT migrate it under `metadata:` — see `references/portability-tiers.md` § "On `argument-hint` placement" for the evidence.
- **No git auto-commit.** All operations leave the working tree dirty for review. The user decides what enters history. Suggest `git diff` after `port` to verify body bytes are untouched.
