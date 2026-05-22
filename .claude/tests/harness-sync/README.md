# harness-sync tests

Spec 016. Scenario-numbered scripts (`NN-<slug>.sh`) map 1:1 to acceptance scenarios in `docs/specs/016-harness-sync/spec.md`. Run individually or via `run-all.sh`. Each script is self-contained: builds a `mktemp -d` fixture (mock Agent0 source + mock fork target), invokes `.claude/tools/sync-harness.sh`, asserts stdout/stderr/exit, cleans up via `trap`.
