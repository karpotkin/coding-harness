# Coding Harness repository instructions

## Purpose

This is karpotkin's clean-history distribution of the Superpowers coding-agent
methodology. `skills/` is the shared behavior layer. Host-specific directories
must remain thin adapters around that layer.

## Rules

- Keep skill wording host-neutral. Put tool-name mappings in the matching adapter reference.
- A behavior change to a skill requires a focused regression or evaluation scenario.
- A new host adapter must load the startup bootstrap automatically and prove that a build request invokes `brainstorming` before writing code.
- Keep versions synchronized across every plugin manifest and marketplace entry.
- Do not commit tokens, credentials, `.env` files, private transcripts, or user data.
- Do not weaken checks to make a change pass.

## Clean code and module boundaries

- Every tracked executable source or test file must stay at or below 700 lines. Split by
  responsibility before adding behavior to a file near the limit; generated data and prose are
  not code.
- Give each module one reason to change. Keep protocol, orchestration, persistence, platform
  adaptation, and presentation concerns in separate focused modules.
- Keep host adapters thin: translate host inputs and outputs, then delegate to shared behavior.
  Shared behavior must not import or branch on a host adapter.
- Apply SOLID boundaries pragmatically: depend on narrow contracts, extend through composition,
  and avoid global mutable state, circular dependencies, generic utility dumping grounds, and
  condition trees that mix unrelated responsibilities.
- Prefer small named pure functions and explicit data flow. Isolate filesystem, process, network,
  clock, and environment access at module edges so core behavior can be tested deterministically.
- Tests assert observable behavior and failure semantics. Keep fixtures and assertion helpers in
  focused test-support modules when they would obscure the scenario under test.

## Local gates

Run the checks relevant to every edited surface. Before a release, run at least:

```bash
bash tests/hooks/test-session-start.sh
bash tests/codex/test-marketplace-manifest.sh
bash tests/kimi/run-tests.sh
bash tests/dsh/run-tests.sh
bash scripts/check-file-lines.sh
```

For every changed skill, run the Skill Creator `quick_validate.py` validator.

## Upstream updates

This repository is intentionally not a GitHub fork. Import upstream releases as
reviewed snapshots, preserve local adapter changes, and commit the result as a
normal repository update.
