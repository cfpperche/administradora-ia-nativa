# Frontmatter validation rules

The rule set that `scripts/validate.sh` checks. Each rule cites the agentskills.io spec (frozen in `references/spec-snapshot.md`) and gives a remediation hint when the rule fails.

A `SKILL.md` file **passes** validation when every rule below evaluates to OK. A single failure causes the validator to exit non-zero and emit one stderr line per failed rule.

## Hard rules (validator blocks on failure)

### Rule 1 — File present and parseable

**Check.** A `SKILL.md` file exists at the path given to the validator, opens successfully, and starts with YAML frontmatter delimited by `---` on the first line and a closing `---` later in the file.

**Spec citation.** `spec-snapshot.md` § "`SKILL.md` format" — "must contain YAML frontmatter followed by Markdown content."

**Failure stderr.** `rule1-frontmatter: SKILL.md missing, empty, or not opened with '---'`

**Remediation.** Ensure the file's first line is exactly `---` (no BOM, no leading whitespace) and that a closing `---` appears before the markdown body.

### Rule 2 — `name` field present and well-formed

**Check.** Inside the frontmatter, a `name:` key exists. Its value:
- Is a single string (not a list or map)
- Is 1-64 characters long
- Matches the regex `^[a-z][a-z0-9]*(-[a-z0-9]+)*$` (lowercase, alphanumeric and hyphens, no leading/trailing/consecutive hyphens)

**Spec citation.** `spec-snapshot.md` § "`name` field rules".

**Failure stderr.**
- `rule2-name-missing: required field 'name' absent from frontmatter`
- `rule2-name-length: 'name' is N chars; must be 1-64`
- `rule2-name-regex: 'name' must match ^[a-z][a-z0-9]*(-[a-z0-9]+)*$; got: '<value>'`

**Remediation.** Add (or fix) the line `name: <kebab-case-skill-name>` directly under the opening `---`. The name should match the directory containing the SKILL.md.

### Rule 3 — `name` matches parent directory

**Check.** The value of `name:` is byte-identical to the basename of the directory containing the SKILL.md.

**Spec citation.** `spec-snapshot.md` § "`name` field rules" — "Must match the parent directory name."

**Failure stderr.** `rule3-name-dirname-mismatch: name '<value>' does not match parent directory '<dirname>'`

**Remediation.** Either rename the directory to match `name:`, or change `name:` to match the directory. The two must be byte-identical.

### Rule 4 — `description` field present and within length

**Check.** Inside the frontmatter, a `description:` key exists. Its value:
- Is a single string
- Is 1-1024 characters long (non-empty)

**Spec citation.** `spec-snapshot.md` § "`description` field rules".

**Failure stderr.**
- `rule4-description-missing: required field 'description' absent from frontmatter`
- `rule4-description-empty: 'description' is empty`
- `rule4-description-length: 'description' is N chars; must be 1-1024`

**Remediation.** Add `description: <what + when>` under `name:`. Use the "what + when" shape from `references/description-best-practices.md`. Trim aggressively if over 1024 chars.

### Rule 5 — `compatibility` (if present) within length

**Check.** If a `compatibility:` key exists in the frontmatter:
- Its value is a single string
- Its length is 1-500 characters

**Spec citation.** `spec-snapshot.md` § "`compatibility` field rules".

**Failure stderr.**
- `rule5-compatibility-length: 'compatibility' is N chars; must be 1-500`
- `rule5-compatibility-empty: 'compatibility' present but empty (omit the key instead)`

**Remediation.** If the value is too long, condense. The field is optional — if there are genuinely no compatibility constraints to declare, remove the key entirely.

### Rule 6 — Frontmatter closes before line 200

**Check.** The closing `---` of the frontmatter appears on or before line 200 of the file. (Sanity check: a frontmatter block dozens of KB long indicates malformed YAML.)

**Spec citation.** None directly — defensive heuristic to catch malformed YAML before the parser blows up.

**Failure stderr.** `rule6-frontmatter-runaway: closing '---' not found before line 200; check YAML syntax`

**Remediation.** Inspect the frontmatter block for unclosed strings, missing colons, broken indentation. The malformed YAML is allowing the parser to keep scanning past the intended close.

## Soft rules (validator warns but does not block in v1)

### Rule 7 — Body under 500 lines (warning)

**Check.** The markdown body (everything after the closing `---`) is fewer than 500 lines.

**Spec citation.** `spec-snapshot.md` § "Progressive disclosure" — "Keep your main `SKILL.md` under 500 lines. Move detailed reference material to separate files."

**Failure stderr.** `rule7-body-warn: body is N lines; recommended max is 500 (consider moving detail to references/)`

**Remediation.** Move long sections (detailed rules, error tables, large examples) to files in `references/` and reference them from SKILL.md. The validator does not enforce this hard in v1; a future spec may.

### Rule 8 — Body under 5000 estimated tokens (warning)

**Check.** A rough byte→token estimate (bytes / 4) suggests the body is under 5000 tokens.

**Spec citation.** `spec-snapshot.md` § "Progressive disclosure" — "< 5000 tokens recommended".

**Failure stderr.** `rule8-body-token-warn: body is ~N estimated tokens; recommended max is 5000`

**Remediation.** Same as Rule 7 — move detail into `references/` files.

## Defer to canonical

When `command -v skills-ref` succeeds, `validate.sh` invokes `skills-ref validate <path>` and surfaces its output verbatim instead of running the rules above. `skills-ref` is the upstream reference implementation maintained by agentskills.io; its rule set is canonical truth.

The bash rule set above is Agent0's interpretation of the spec for the zero-dep case. If `skills-ref` and the bash rules disagree on a specific file, **`skills-ref` wins** — re-snapshot the spec and reconcile the bash rules.

## Exit code contract

- **Exit 0:** every hard rule passed. Soft-rule warnings (if any) printed to stderr but do not affect the exit code.
- **Exit non-zero (the bash validator uses 1):** at least one hard rule failed. Each failure has one stderr line in the format `ruleN-<short-id>: <human message>`.

Downstream consumers (`/skill audit`, `/skill port` confirmation gates, CI hooks) read the exit code as the binary signal; stderr is structured for grep-ability per rule ID.
