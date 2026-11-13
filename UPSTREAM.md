# Upstream maintenance

Current baseline: `obra/superpowers` release `v7.0.2`.

Local distribution additions:

- independent repository and marketplace identity;
- portable root `plugin.json`;
- DeepSeek Harness bundle, tool mapping, packaging checks, and documentation;
- installation links targeting `karpotkin/coding-harness`.

When updating the baseline:

1. Compare the next upstream release with the current baseline.
2. Import only reviewed changes and preserve `LICENSE` plus `NOTICE.md`.
3. Reapply or reconcile the local additions above.
4. Run the local gates from `AGENTS.md` and validate all changed skills.
5. Update this baseline note, manifests, documentation pins, and the release tag together.
