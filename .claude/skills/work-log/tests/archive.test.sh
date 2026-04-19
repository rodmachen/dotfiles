#!/usr/bin/env bash
# archive.test.sh — tests for scan.sh's auto-archive of complete plans
# Usage: bash tests/archive.test.sh
# Requires: git, jq, python3

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_SH="$SCRIPT_DIR/../scan.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo -e "  ${GREEN}PASS${NC} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $desc"
    echo "       expected: [$expected]"
    echo "       actual:   [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo -e "  ${GREEN}PASS${NC} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $desc"
    echo "       expected file to exist: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_absent() {
  local desc="$1" path="$2"
  if [[ ! -f "$path" ]]; then
    echo -e "  ${GREEN}PASS${NC} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $desc"
    echo "       expected file to NOT exist: $path"
    FAIL=$((FAIL + 1))
  fi
}

# --- Sandbox setup ---

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

# Create a repo on a specific branch.
# Usage: make_repo_on <name> <branch>
make_repo_on() {
  local name="$1" branch="$2"
  local dir="$SANDBOX/$name"
  mkdir -p "$dir"
  git -C "$dir" init -q -b "$branch"
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  echo "# $name" > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -q -m "Initial commit"
}

add_plan() {
  local repo_dir="$1" plan_name="$2" plan_content="$3"
  mkdir -p "$repo_dir/docs/plans"
  printf '%s\n' "$plan_content" > "$repo_dir/docs/plans/$plan_name"
  git -C "$repo_dir" add "docs/plans/$plan_name"
  git -C "$repo_dir" commit -q -m "Add plan $plan_name"
}

COMPLETE_PLAN='# Plan

## Steps

### Step 1 — First ✅
Done.

### Step 2 — Second ✅
Done.

### Step 3 — Third ✅
Done.'

INCOMPLETE_PLAN='# Plan

## Steps

### Step 1 — First ✅
Done.

### Step 2 — Second
Not done.'

# delta: clean, feature branch, complete plan → should be archived
make_repo_on "repo-delta" "feature/ship-it"
add_plan "$SANDBOX/repo-delta" "done.md" "$COMPLETE_PLAN"

# epsilon: clean, on main, complete plan → should be skipped (on main)
make_repo_on "repo-epsilon" "main"
add_plan "$SANDBOX/repo-epsilon" "done.md" "$COMPLETE_PLAN"

# zeta: dirty plan file, feature branch, complete plan → should be skipped (dirty)
make_repo_on "repo-zeta" "feature/in-flight"
add_plan "$SANDBOX/repo-zeta" "done.md" "$COMPLETE_PLAN"
# Make the plan file dirty (modify tracked file without staging)
printf '\nextra uncommitted line\n' >> "$SANDBOX/repo-zeta/docs/plans/done.md"

# eta: clean, feature branch, incomplete plan → should NOT be touched
make_repo_on "repo-eta" "feature/wip"
add_plan "$SANDBOX/repo-eta" "wip.md" "$INCOMPLETE_PLAN"

# theta: clean, on master (not main), complete plan → should be skipped (on master)
make_repo_on "repo-theta" "master"
add_plan "$SANDBOX/repo-theta" "done.md" "$COMPLETE_PLAN"

# --- Phase 1: Dry-run. No file moves should occur. ---

echo "=== archive.test.sh ==="
echo ""
echo "--- Phase 1: WORKLOG_DRYRUN=1 (no moves should happen) ---"

DRY_OUTPUT=$(WORKLOG_DRYRUN=1 "$SCAN_SH" "$SANDBOX")

DELTA_DRY=$(echo "$DRY_OUTPUT" | jq '.[] | select(.name == "repo-delta")')
assert_eq "delta: archives.moved length=1 (dry-run)" \
  "1" "$(echo "$DELTA_DRY" | jq '.archives.moved | length')"
assert_eq "delta: archives.moved[0].file" \
  "done.md" "$(echo "$DELTA_DRY" | jq -r '.archives.moved[0].file')"
assert_eq "delta: archives.moved[0].dryrun=true" \
  "true" "$(echo "$DELTA_DRY" | jq '.archives.moved[0].dryrun')"

# File system should be UNCHANGED during dry-run
assert_file_exists "delta: plan file still at original location after dry-run" \
  "$SANDBOX/repo-delta/docs/plans/done.md"
assert_file_absent "delta: archive dir NOT created during dry-run" \
  "$SANDBOX/repo-delta/docs/plans/archive/done.md"

# Epsilon (on main) should be skipped even in dry-run
EPSILON_DRY=$(echo "$DRY_OUTPUT" | jq '.[] | select(.name == "repo-epsilon")')
assert_eq "epsilon: archives.skipped length=1 (dry-run)" \
  "1" "$(echo "$EPSILON_DRY" | jq '.archives.skipped | length')"
assert_eq "epsilon: skipped reason mentions main" \
  "on main" "$(echo "$EPSILON_DRY" | jq -r '.archives.skipped[0].reason')"

# --- Phase 2: Live run. Deltas should actually move. ---

echo ""
echo "--- Phase 2: live run ---"

OUTPUT=$("$SCAN_SH" "$SANDBOX")

echo ""
echo "--- repo-delta (feature branch, clean, complete → moved) ---"

DELTA=$(echo "$OUTPUT" | jq '.[] | select(.name == "repo-delta")')
assert_eq "delta: archives.moved length=1" \
  "1" "$(echo "$DELTA" | jq '.archives.moved | length')"
assert_eq "delta: archives.moved[0].file" \
  "done.md" "$(echo "$DELTA" | jq -r '.archives.moved[0].file')"
assert_eq "delta: archives.skipped is empty" \
  "0" "$(echo "$DELTA" | jq '.archives.skipped | length')"
assert_eq "delta: plans array now empty (archived plan excluded)" \
  "0" "$(echo "$DELTA" | jq '.plans | length')"

assert_file_absent "delta: plan moved from docs/plans/done.md" \
  "$SANDBOX/repo-delta/docs/plans/done.md"
assert_file_exists "delta: plan now at docs/plans/archive/done.md" \
  "$SANDBOX/repo-delta/docs/plans/archive/done.md"

# After git mv, working tree is dirty with a staged rename
assert_eq "delta: working tree now dirty (staged rename)" \
  "true" "$(echo "$DELTA" | jq '.dirty')"

echo ""
echo "--- repo-epsilon (on main, complete → skipped) ---"

EPSILON=$(echo "$OUTPUT" | jq '.[] | select(.name == "repo-epsilon")')
assert_eq "epsilon: archives.moved is empty" \
  "0" "$(echo "$EPSILON" | jq '.archives.moved | length')"
assert_eq "epsilon: archives.skipped length=1" \
  "1" "$(echo "$EPSILON" | jq '.archives.skipped | length')"
assert_eq "epsilon: skipped.reason=on main" \
  "on main" "$(echo "$EPSILON" | jq -r '.archives.skipped[0].reason')"
assert_eq "epsilon: skipped.file=done.md" \
  "done.md" "$(echo "$EPSILON" | jq -r '.archives.skipped[0].file')"
assert_eq "epsilon: plan still in plans array" \
  "1" "$(echo "$EPSILON" | jq '.plans | length')"

assert_file_exists "epsilon: plan file untouched" \
  "$SANDBOX/repo-epsilon/docs/plans/done.md"
assert_file_absent "epsilon: no archive dir created" \
  "$SANDBOX/repo-epsilon/docs/plans/archive/done.md"

echo ""
echo "--- repo-zeta (dirty plan, feature, complete → skipped) ---"

ZETA=$(echo "$OUTPUT" | jq '.[] | select(.name == "repo-zeta")')
assert_eq "zeta: archives.skipped length=1" \
  "1" "$(echo "$ZETA" | jq '.archives.skipped | length')"
assert_eq "zeta: skipped.reason mentions dirty" \
  "dirty working tree for plan file" "$(echo "$ZETA" | jq -r '.archives.skipped[0].reason')"
assert_file_exists "zeta: plan file untouched" \
  "$SANDBOX/repo-zeta/docs/plans/done.md"

echo ""
echo "--- repo-eta (incomplete plan → untouched) ---"

ETA=$(echo "$OUTPUT" | jq '.[] | select(.name == "repo-eta")')
assert_eq "eta: archives.moved empty" \
  "0" "$(echo "$ETA" | jq '.archives.moved | length')"
assert_eq "eta: archives.skipped empty" \
  "0" "$(echo "$ETA" | jq '.archives.skipped | length')"
assert_eq "eta: plan still in plans (in-progress)" \
  "1" "$(echo "$ETA" | jq '.plans | length')"
assert_eq "eta: plan status still in-progress" \
  "in-progress" "$(echo "$ETA" | jq -r '.plans[0].status')"
assert_file_exists "eta: plan file untouched" \
  "$SANDBOX/repo-eta/docs/plans/wip.md"

echo ""
echo "--- repo-theta (on master, complete → skipped) ---"

THETA=$(echo "$OUTPUT" | jq '.[] | select(.name == "repo-theta")')
assert_eq "theta: archives.skipped length=1" \
  "1" "$(echo "$THETA" | jq '.archives.skipped | length')"
assert_eq "theta: skipped.reason=on master" \
  "on master" "$(echo "$THETA" | jq -r '.archives.skipped[0].reason')"
assert_file_exists "theta: plan file untouched" \
  "$SANDBOX/repo-theta/docs/plans/done.md"

# --- Summary ---

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}All $PASS tests passed.${NC}"
  exit 0
else
  echo -e "${RED}$FAIL of $((PASS + FAIL)) tests failed.${NC}"
  exit 1
fi
