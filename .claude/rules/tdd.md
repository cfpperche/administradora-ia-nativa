# Test-driven development

Production code lands with a test that exercises it. The discipline is cultural, not enforced by a blocking gate — the validator notices when prod files moved without test files in the same diff and emits a non-blocking advisory. The agent (or human) reading the advisory decides whether the change was genuinely test-exempt or whether the test was forgotten.

## Red → Green → Refactor

Write a failing test first. The test names the behavior, the failure proves the behavior is missing. Then write the smallest production change that makes the test pass — green. Once green, refactor freely; the test is now a safety net, not the goal. Commit the red-to-green transition as one logical unit so reviewers see the contract and the implementation together.

The loop is short on purpose. A red phase that lasts more than a few minutes is a sign the test is too big — split it. A refactor phase that breaks the test means the refactor changed behavior, not structure — back out, write a test for the new behavior, then resume. Lineage: Kent Beck, *Test-Driven Development: By Example* (2002); cited for the formulation, not as a tooling endorsement.

## When TDD applies

Apply for any change that meets at least one of:

- Modifies production code paths (the file is reachable from a public entrypoint, not a build script or fixture)
- Changes a public API, schema, or wire contract
- Has user-visible behavior change worth describing in a PR body
- Fixes a bug — write the regression test first, watch it fail, then fix; the test stays as the proof the bug cannot silently return
- Implements a scenario from `spec.md` (the scenario title is the test name; see below)

When the change spans both prod and test, write the test first even when the production sketch is already in your head. The order matters: a test written after a passing implementation is biased toward the implementation's shape, not the behavior's contract.

## When to skip

Same as `.claude/rules/spec-driven.md` § *When to skip*, plus comment-only edits and dependency bumps without behavior change. The SDD skip list is the source of truth — do not duplicate it here; if it grows, this rule inherits the change.

## From scenarios to tests

BDD scenarios in `spec.md` (see `.claude/rules/spec-driven.md` § *Acceptance scenarios*) describe observable behavior in Given/When/Then prose. TDD test names mirror those scenarios verbatim, so the bridge from spec to executable test is mechanical. A scenario titled `**Scenario: foo when bar**` becomes:

```
test('foo when bar', ...)        // JS / TS — jest, vitest, etc.
def test_foo_when_bar(...):      # Python — pytest, unittest
```

The exact mapping is dictated by the project's chosen test framework — kebab-case file names, snake_case method names, suite-level `describe` blocks all count. The point is that a reader holding both `spec.md` and the test file can match scenarios to tests by eye, with no translation step. One scenario maps to one test by default; if a scenario decomposes into several Then-clauses worth asserting independently, split it into multiple tests rather than crowding a single assertion block.

The validator's per-language test-pattern table (the heuristic that drives the advisory in the next section) recognises the common conventions out of the box: `*.test.ts|tsx|js|jsx`, `*.spec.*`, and `__tests__/`/`tests/`/`test/` for the JS/TS family; `*_test.py`, `test_*.py`, and `tests/` for Python; `*_test.go` for Go; `tests/` and `*_test.rs`/`*_tests.rs` for Rust; `tests/`, `*Test.php`, and `*_test.php` for PHP (covers PHPUnit + Pest conventions and Laravel's `tests/Feature/` + `tests/Unit/` layout). Files matching none of these (and not on the doc/config exclusion list — `*.md`, `*.json`, `*.yml`, `LICENSE`, etc.) are treated as prod. Project conventions outside that table need the env-var override documented in § *Gotchas*.

## Reading the validator advisory

When a delegated sub-agent edits a file, `.claude/hooks/post-edit-validate.sh` invokes `.claude/validators/run.sh`. On a stack-detected project, the validator inspects `git diff --name-only`, classifies each changed file as prod or test using language-aware patterns, and if prod files changed without any test files in the same diff appends a `warnings` entry of kind `no_test_change_for_prod_edit` to its JSON output. The hook reads the array on the exit-0 path and echoes each `message` to stderr prefixed with `tdd-advisory:`. The harness surfaces hook stderr to the agent's next turn, so the advisory shows up in context the moment the edit completes.

The advisory is informational. The hook always returns exit 0 — warnings never block, never increment the loop-budget counter, never affect the validator `ok` field. When you see a `tdd-advisory:` line, add a test that exercises the change before declaring done, unless the edit is genuinely test-exempt (see § *When to skip*) or you have already documented the exemption (see § *When to override*). Ignoring the advisory and declaring done is the failure mode this discipline exists to surface.

The advisory message names the prod files that triggered it (the `files` field on the warning entry) so you can act on the signal without re-running `git diff` yourself. If the listed files are not what you expected — for example, a generated artifact you forgot to gitignore — the right fix is usually a `.gitignore` entry, not a test stub.

## When to override

Same shape as the governance and delegation gates (see `.claude/hooks/governance-gate.sh`): a line `# OVERRIDE: <reason ≥10 chars>` in the brief or commit context. By convention for TDD-exempt work, the reason text starts with `tdd-exempt:` so reviewers can grep the audit log for deliberate skips — for example `# OVERRIDE: tdd-exempt: rename only, no behavior change`. The prefix is a soft, human-readable convention; no script parses it.

The validator may still emit the advisory because the heuristic is purely diff-shape — it does not read commit messages or briefs. That is fine. The override marker plus the recorded reason in the delegation audit log (`override` field on the dispatch entry, see `.claude/rules/delegation.md` § *Audit log*) is the documentation that the warning was deliberate. Reviewers correlate the two when auditing — match a `tdd-advisory:` in session output against the `tdd-exempt:` reason in the audit row, confirm the decision was made consciously, move on.

## Gotchas

- **`git diff --name-only` lumps parent and sub-agent edits together.** The validator sees one diff per session, not per actor. A sub-agent that edits prod while the parent edits the corresponding tests in the same diff produces no warning (correct outcome — coverage exists). The inverse — sub-agent edits prod while the parent edits docs or unrelated tests — also produces no warning (false negative — the sub-agent should have written its own test). The first iteration accepts this imprecision; per-agent edit tracking was considered and deferred. Revisit if real usage shows the false negative happening often enough to matter.
- **`CLAUDE_TDD_TEST_PATTERNS` overrides the language defaults.** Set to a space-separated list of globs when the project's test naming does not match the built-in table (e.g., `Foo.tests.ts` next to source, or `spec/` instead of `tests/`). When set, the env var fully replaces the per-language defaults — include every pattern the project considers a test file, not just the additions, otherwise the default table is gone and ordinary `*.test.ts` files start being classified as prod.
- **The validator is inert in this base repo.** No language stack is detected, so no warnings fire. The discipline ships dormant; it activates as soon as a real project plugs in a stack.
- **No git repo, no warning.** If `git rev-parse --git-dir` fails, the validator skips the diff classification entirely. Acceptable for throwaway scratch dirs; do not rely on it as a way to silence the advisory in real projects.
- **The advisory does not gate the loop-budget counter.** The post-edit validator's consecutive-failure counter (see `.claude/rules/delegation.md` § *Post-edit validator loop*) only increments on `ok=false`. A persistent `tdd-advisory:` stream will not trip the budget — it remains a soft signal even when repeated. Treat repeated advisories as a habit problem, not a tooling failure.
