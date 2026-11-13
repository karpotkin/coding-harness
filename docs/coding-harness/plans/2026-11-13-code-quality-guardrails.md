# Code Quality Guardrails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Enforce focused module boundaries, SOLID-style dependency direction, and a hard 700-line limit for executable source and test files.

**Architecture:** Keep host adapters thin and shared behavior in focused modules. Add one repository-wide line-count gate, then split the three current violations along existing responsibility boundaries without changing their behavior.

**Tech Stack:** Bash, CommonJS, Node.js built-ins, existing shell and Node test suites.

**Spec:** User request dated 2026-11-13 and repository rules in `AGENTS.md`.

## Global Constraints

- Every tracked executable source or test file must contain at most 700 lines.
- Tests remain behavioral and retain their current assertions.
- Host adapters depend on shared behavior; shared behavior must not depend on a host adapter.
- No new runtime dependency is allowed.
- Existing public entrypoints remain compatible.

## Review Focus

- Extensionless shell executables must be included in the line-count gate.
- Documentation, JSON, generated data, and binary assets must not be misclassified as code.
- Paths containing spaces must be handled safely.
- Extracted shell helpers must preserve cleanup, globals, exit codes, and assertion counts.
- The WebSocket module must preserve RFC 6455 frame limits and server integration.

---

### Task 1: Repository quality policy and line-count gate

**Files:**
- Modify: `AGENTS.md`
- Modify: `.pre-commit-config.yaml`
- Create: `scripts/check-file-lines.sh`
- Create: `tests/file-lines/test-check-file-lines.sh`

**Interfaces:**
- Consumes: tracked files reported by Git.
- Produces: `bash scripts/check-file-lines.sh`, exiting non-zero and listing every executable code file over 700 lines.

- [ ] Write fixture tests for an allowed file, an oversized file, an extensionless shell executable, and paths with spaces.
- [ ] Run the fixture test and verify RED because the gate does not exist.
- [ ] Implement the gate with a 700-line default and tracked-file-safe iteration.
- [ ] Add the clean-code, module-boundary, SOLID, and test expectations to `AGENTS.md`.
- [ ] Register the gate as a local pre-commit hook and run the fixture test.

### Task 2: Extract the WebSocket protocol module

**Files:**
- Create: `skills/brainstorming/scripts/websocket-protocol.cjs`
- Modify: `skills/brainstorming/scripts/server.cjs`
- Modify: `tests/brainstorm-server/ws-protocol.test.js`

**Interfaces:**
- Produces: `computeAcceptKey`, `encodeFrame`, `decodeFrame`, `OPCODES`, and `MAX_FRAME_PAYLOAD_BYTES` from `websocket-protocol.cjs`.
- Consumes: the same interface from `server.cjs` for HTTP upgrade and message handling.

- [ ] Point the protocol test at the new module and verify RED because it does not exist.
- [ ] Move only RFC 6455 constants and pure codec functions into the module.
- [ ] Import the module from the server and preserve server exports used by callers.
- [ ] Run the protocol and complete brainstorm-server suites.

### Task 3: Split oversized shell regression suites

**Files:**
- Create: `tests/codex-plugin-sync/fixtures.sh`
- Modify: `tests/codex-plugin-sync/test-sync-to-codex-plugin.sh`
- Create: `tests/claude-code/sdd-workspace-repository-scenarios.sh`
- Modify: `tests/claude-code/test-sdd-workspace.sh`

**Interfaces:**
- `fixtures.sh` provides repository fixture builders and command runners used by the Codex sync test.
- `run_repository_boundary_scenarios(repo, wt_root, wt, wt_base, wt_head)` owns boundary, ownership-marker, and no-exec scenarios for the SDD workspace test.

- [ ] Extract the Codex fixture responsibility into one sourced helper and run its regression suite.
- [ ] Extract the SDD repository-boundary scenarios behind an explicit function interface and run its regression suite.
- [ ] Run the line-count gate and confirm every executable code file is at most 700 lines.
- [ ] Run all repository release gates and commit the verified result.
