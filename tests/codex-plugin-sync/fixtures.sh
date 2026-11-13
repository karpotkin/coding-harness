#!/usr/bin/env bash

configure_git_identity() {
    local repo="$1"

    git -C "$repo" config user.name "Test Bot"
    git -C "$repo" config user.email "test@example.com"
}

init_repo() {
    local repo="$1"

    git init -q -b main "$repo"
    configure_git_identity "$repo"
}

commit_fixture() {
    local repo="$1"
    local message="$2"

    git -C "$repo" commit -q -m "$message"
}

checkout_fixture_branch() {
    local repo="$1"
    local branch="$2"

    git -C "$repo" checkout -q -b "$branch"
}

write_fake_gh() {
    local bin_dir="$1"

    mkdir -p "$bin_dir"

    cat > "$bin_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then
    exit 0
fi

echo "unexpected gh invocation: $*" >&2
exit 1
EOF

    chmod +x "$bin_dir/gh"
}

run_preview() {
    local upstream="$1"
    local dest="$2"
    local fake_bin="$3"

    PATH="$fake_bin:$PATH" "$BASH_UNDER_TEST" "$upstream/scripts/sync-to-codex-plugin.sh" -n --local "$dest" 2>&1
}

run_bootstrap_preview() {
    local upstream="$1"
    local dest="$2"
    local fake_bin="$3"

    PATH="$fake_bin:$PATH" "$BASH_UNDER_TEST" "$upstream/scripts/sync-to-codex-plugin.sh" -n --bootstrap --local "$dest" 2>&1
}

run_preview_without_manifest() {
    local upstream="$1"
    local dest="$2"
    local fake_bin="$3"

    rm -f "$upstream/.codex-plugin/plugin.json"
    PATH="$fake_bin:$PATH" "$BASH_UNDER_TEST" "$upstream/scripts/sync-to-codex-plugin.sh" -n --local "$dest" 2>&1
}

run_preview_with_stale_ignored_destination() {
    local upstream="$1"
    local dest="$2"
    local fake_bin="$3"

    PATH="$fake_bin:$PATH" "$BASH_UNDER_TEST" "$upstream/scripts/sync-to-codex-plugin.sh" -n --local "$dest" 2>&1
}

run_apply() {
    local upstream="$1"
    local dest="$2"
    local fake_bin="$3"

    PATH="$fake_bin:$PATH" "$BASH_UNDER_TEST" "$upstream/scripts/sync-to-codex-plugin.sh" -y --local "$dest" 2>&1
}

run_help() {
    local upstream="$1"
    local fake_bin="$2"

    PATH="$fake_bin:$PATH" "$BASH_UNDER_TEST" "$upstream/scripts/sync-to-codex-plugin.sh" --help 2>&1
}

write_bootstrap_destination_fixture() {
    local repo="$1"

    printf 'bootstrap fixture\n' > "$repo/README.md"
    git -C "$repo" add README.md

    commit_fixture "$repo" "Initial bootstrap destination fixture"
}
