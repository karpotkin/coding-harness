#!/usr/bin/env bash

run_repository_boundary_scenarios() {
    local repo="$1"
    local wt_root="$2"
    local wt="$3"
    local wt_base="$4"
    local wt_head="$5"
    local rc=0

    # Run from outside any repository (e.g. the skill's own directory in an
    # installed plugin), the scripts stop even when the plan's absolute path
    # is inside a repository: like git, they act on the current directory's
    # working tree (or -C DIR), never on one guessed from the plan.
    local nonrepo="$TEST_ROOT/not-a-repo"
    mkdir -p "$nonrepo"
    local nr_msg="SDD scripts must run from inside the git working tree you're executing in, with at least one commit (current directory: $nonrepo). If this is a new project, run 'git init' and make a first commit, then rerun."
    local nr_before nr_cmd nr_err
    nr_before="$(find "$wt_root/.superpowers" | sort)"
    for nr_cmd in "sdd-workspace $wt/plan-a.md" "task-brief $wt/plan-a.md 1" "review-package $wt/plan-a.md $wt_base $wt_head"; do
        rc=0
        # shellcheck disable=SC2086 # nr_cmd is a fixed script name plus its arguments
        nr_err="$(cd "$nonrepo" && "$SDD_SCRIPTS"/$nr_cmd 2>&1 >/dev/null)" || rc=$?
        if [[ "$rc" -eq 2 && "$nr_err" == "$nr_msg"$'\n'"git said: fatal: not a git repository"* ]]; then
            pass "${nr_cmd%% *} outside any repository stops with the shared message despite a plan in a repository"
        else
            fail "${nr_cmd%% *} outside any repository stops with the shared message despite a plan in a repository"
            echo "    exit: $rc"
            echo "    stderr: $nr_err"
        fi
    done
    if [[ ! -e "$nonrepo/.superpowers" && "$(find "$wt_root/.superpowers" | sort)" == "$nr_before" ]]; then
        pass "outside any repository, nothing is written to the cwd or the plan's repository"
    else
        fail "outside any repository, nothing is written to the cwd or the plan's repository"
    fi

    # No repository anywhere: a greenfield plan before Task 1 (#2242).
    local gf="$TEST_ROOT/greenfield"
    mkdir -p "$gf"
    printf '## Task 1: Scaffold the repo\n\nCreate files.\n' > "$gf/plan.md"
    local no_repo_msg="SDD scripts must run from inside the git working tree you're executing in, with at least one commit (current directory: $gf). If this is a new project, run 'git init' and make a first commit, then rerun."
    local cmd gf_err
    for cmd in "sdd-workspace plan.md" "task-brief plan.md 1"; do
        local script=${cmd%% *}
        rc=0
        # shellcheck disable=SC2086 # cmd is a fixed script name plus its arguments
        gf_err="$(cd "$gf" && "$SDD_SCRIPTS"/$cmd 2>&1 >/dev/null)" || rc=$?
        if [[ "$rc" -eq 2 && "$gf_err" == "$no_repo_msg"$'\n'"git said: fatal: not a git repository"* ]]; then
            pass "$script outside any repository exits 2 naming both fixes"
        else
            fail "$script outside any repository exits 2 naming both fixes"
            echo "    exit: $rc"
            echo "    stderr: $gf_err"
        fi
    done
    rc=0
    gf_err="$(cd "$gf" && "$SDD_SCRIPTS/review-package" plan.md HEAD~1 HEAD 2>&1 >/dev/null)" || rc=$?
    if [[ "$rc" -eq 2 && "$gf_err" == "$no_repo_msg"$'\n'"git said: fatal: not a git repository"* ]]; then
        pass "review-package outside any repository exits 2 naming both fixes"
    else
        fail "review-package outside any repository exits 2 naming both fixes"
        echo "    exit: $rc"
        echo "    stderr: $gf_err"
    fi
    if [[ ! -e "$gf/.superpowers" ]]; then
        pass "nothing is written outside a repository"
    else
        fail "nothing is written outside a repository"
        find "$gf/.superpowers" | sed 's/^/    /'
    fi

    # A repository with no commit yet has no range to review.
    git init -q -b main "$gf"
    rc=0
    gf_err="$(cd "$gf" && "$SDD_SCRIPTS/review-package" plan.md HEAD~1 HEAD 2>&1 >/dev/null)" || rc=$?
    if [[ "$rc" -eq 2 && "$gf_err" == "$no_repo_msg"$'\n'"git said: fatal: "* && ! -e "$gf/.superpowers" ]]; then
        pass "review-package in a repository with no commit exits 2 with the same message"
    else
        fail "review-package in a repository with no commit exits 2 with the same message"
        echo "    exit: $rc"
        echo "    stderr: $gf_err"
    fi

    # A repository Git refuses must surface Git's own reason.
    local dub_err dub_msg="SDD scripts must run from inside the git working tree you're executing in, with at least one commit (current directory: $repo). If this is a new project, run 'git init' and make a first commit, then rerun."
    if (cd "$repo" && GIT_TEST_ASSUME_DIFFERENT_OWNER=1 git rev-parse --show-toplevel >/dev/null 2>&1); then
        echo "  [SKIP] git refusing a dubious-ownership repo ($(git --version) ignores GIT_TEST_ASSUME_DIFFERENT_OWNER)"
    else
        rc=0
        dub_err="$(cd "$repo" && GIT_TEST_ASSUME_DIFFERENT_OWNER=1 "$SDD_SCRIPTS/sdd-workspace" plan-a.md 2>&1 >/dev/null)" || rc=$?
        if [[ "$rc" -eq 2 && "$dub_err" == "$dub_msg"$'\n'"git said: fatal: detected dubious ownership in repository at "* ]]; then
            pass "a repository git refuses as dubious stops with the shared message plus git's reason"
        else
            fail "a repository git refuses as dubious stops with the shared message plus git's reason"
            echo "    exit: $rc"
            echo "    stderr: $dub_err"
        fi
    fi

    # Helpers survive an extractor dropping executable bits (#2040).
    local stripped="$TEST_ROOT/stripped-scripts"
    mkdir -p "$stripped"
    cp "$SDD_SCRIPTS/sdd-repo" "$SDD_SCRIPTS/sdd-workspace" "$SDD_SCRIPTS/task-brief" "$SDD_SCRIPTS/review-package" "$stripped/"
    chmod -x "$stripped"/*
    local noexec_out noexec_rc=0
    noexec_out="$(cd "$repo" && bash "$stripped/task-brief" plan-b.md 1 2>&1)" || noexec_rc=$?
    if [[ "$noexec_rc" -eq 0 && -f "$repo/.superpowers/sdd/plan-b/task-1-brief.md" ]]; then
        pass "task-brief works with no exec bit on sdd-workspace"
    else
        fail "task-brief works with no exec bit on sdd-workspace"
        echo "    rc: $noexec_rc"
        echo "    output: $noexec_out"
    fi

    # Ownership markers: two plans with the same basename (#2045).
    mkdir -p "$repo/docs/alpha" "$repo/docs/beta"
    cat > "$repo/docs/alpha/plan.md" <<'PLAN'
# Alpha Plan

## Task 1: Alpha work

Alpha-only requirement text.
PLAN
    cat > "$repo/docs/beta/plan.md" <<'PLAN'
# Beta Plan

## Task 1: Beta work

Beta-only requirement text.
PLAN

    local dir_alpha dir_beta
    dir_alpha="$(cd "$repo" && "$SDD_SCRIPTS/sdd-workspace" docs/alpha/plan.md)"
    dir_beta="$(cd "$repo" && "$SDD_SCRIPTS/sdd-workspace" docs/beta/plan.md)"
    if [[ "$dir_alpha" != "$dir_beta" ]]; then
        pass "same-basename plans resolve to distinct workspaces"
    else
        fail "same-basename plans resolve to distinct workspaces"
        echo "    alpha: $dir_alpha"
        echo "    beta:  $dir_beta"
    fi

    ( cd "$repo" && "$SDD_SCRIPTS/task-brief" docs/alpha/plan.md 1 >/dev/null )
    ( cd "$repo" && "$SDD_SCRIPTS/task-brief" docs/beta/plan.md 1 >/dev/null )
    if grep -q "Alpha-only requirement text." "$dir_alpha/task-1-brief.md" 2>/dev/null \
        && grep -q "Beta-only requirement text." "$dir_beta/task-1-brief.md" 2>/dev/null; then
        pass "same-basename plans keep both task briefs intact"
    else
        fail "same-basename plans keep both task briefs intact"
        echo "    alpha brief: $(cat "$dir_alpha/task-1-brief.md" 2>/dev/null)"
        echo "    beta brief:  $(cat "$dir_beta/task-1-brief.md" 2>/dev/null)"
    fi
}
