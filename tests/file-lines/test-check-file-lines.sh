#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECK_SCRIPT="$REPO_ROOT/scripts/check-file-lines.sh"
TEST_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

write_lines() {
    local path="$1"
    local count="$2"
    local line="$3"
    local i

    : > "$path"
    for ((i = 0; i < count; i++)); do
        printf '%s\n' "$line" >> "$path"
    done
}

init_fixture() {
    local repo="$1"

    mkdir -p "$repo/src" "$repo/docs"
    git init -q -b main "$repo"
}

allowed_repo="$TEST_ROOT/allowed"
init_fixture "$allowed_repo"
write_lines "$allowed_repo/src/small.js" 700 'const value = 1;'
write_lines "$allowed_repo/docs/large.md" 701 'documentation'
git -C "$allowed_repo" add .

allowed_output="$(bash "$CHECK_SCRIPT" "$allowed_repo" 2>&1)" \
    || fail "700-line code and oversized documentation should pass: $allowed_output"
[[ "$allowed_output" == *"All tracked code files are within 700 lines."* ]] \
    || fail "success output should name the 700-line limit: $allowed_output"

oversized_repo="$TEST_ROOT/oversized"
init_fixture "$oversized_repo"
write_lines "$oversized_repo/src/file with spaces.js" 701 'const value = 1;'
printf '#!/usr/bin/env bash\n' > "$oversized_repo/run-check"
for ((i = 0; i < 700; i++)); do
    printf ':\n' >> "$oversized_repo/run-check"
done
git -C "$oversized_repo" add .

oversized_status=0
oversized_output="$(bash "$CHECK_SCRIPT" "$oversized_repo" 2>&1)" || oversized_status=$?
[[ "$oversized_status" -eq 1 ]] || fail "oversized tracked code should exit 1, got $oversized_status"
[[ "$oversized_output" == *$'701\tsrc/file with spaces.js'* ]] \
    || fail "output should report the oversized path with spaces: $oversized_output"
[[ "$oversized_output" == *$'701\trun-check'* ]] \
    || fail "output should include extensionless shell executables: $oversized_output"

echo "PASS: tracked code line limit handles code, docs, shebangs, and spaces"
