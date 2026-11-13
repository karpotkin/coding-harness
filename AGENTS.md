# Coding Harness repository instructions

## Purpose

This is Karpotkin's clean-history distribution of the Superpowers coding-agent
methodology. `skills/` is the shared behavior layer. Host-specific directories
must remain thin adapters around that layer.

## Rules

- Preserve `LICENSE` and `NOTICE.md`; imported upstream code requires its MIT notice.
- Keep skill wording host-neutral. Put tool-name mappings in the matching adapter reference.
- A behavior change to a skill requires a focused regression or evaluation scenario.
- A new host adapter must load the startup bootstrap automatically and prove that a build request invokes `brainstorming` before writing code.
- Keep versions synchronized across every plugin manifest and marketplace entry.
- Do not commit tokens, credentials, `.env` files, private transcripts, or user data.
- Do not weaken checks to make a change pass.

## Local gates

Run the checks relevant to every edited surface. Before a release, run at least:

```bash
bash tests/hooks/test-session-start.sh
bash tests/codex/test-marketplace-manifest.sh
bash tests/kimi/run-tests.sh
bash tests/dsh/run-tests.sh
```

For every changed skill, run the Skill Creator `quick_validate.py` validator.

## Upstream updates

This repository is intentionally not a GitHub fork. Import upstream releases as
reviewed snapshots, retain provenance in `NOTICE.md`, preserve local adapter
changes, and commit the result as a normal repository update.
