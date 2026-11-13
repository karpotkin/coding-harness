#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MAX_LINES=700
violations=()

is_code_file() {
    local path="$1"
    local full_path="$2"
    local first_line

    case "$path" in
        *.js|*.mjs|*.cjs|*.jsx|*.ts|*.tsx|*.py|*.sh|*.bash|*.zsh|*.ps1|*.rb|*.cmd|*.bat)
            return 0
            ;;
    esac

    IFS= read -r first_line < "$full_path" || true
    case "$first_line" in
        '#!'*bash*|'#!'*sh|'#!'*python*|'#!'*node*) return 0 ;;
        *) return 1 ;;
    esac
}

git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "ERROR: not a Git repository: $REPO_ROOT" >&2
    exit 2
}

while IFS= read -r -d '' path; do
    full_path="$REPO_ROOT/$path"
    [[ -f "$full_path" ]] || continue
    is_code_file "$path" "$full_path" || continue

    line_count="$(wc -l < "$full_path" | tr -d ' ')"
    if ((line_count > MAX_LINES)); then
        violations+=("${line_count}"$'\t'"${path}")
    fi
done < <(git -C "$REPO_ROOT" ls-files -z)

if ((${#violations[@]} > 0)); then
    echo "Code files over ${MAX_LINES} lines:" >&2
    printf '%s\n' "${violations[@]}" | LC_ALL=C sort -nr >&2
    exit 1
fi

echo "All tracked code files are within ${MAX_LINES} lines."
