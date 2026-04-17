#!/usr/bin/env bash
# scan.test.sh — integration tests for scan.sh
# Usage: bash tests/scan.test.sh
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

# --- Sandbox setup ---

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

make_repo() {
  local name="$1"
  local dir="$SANDBOX/$name"
  mkdir -p "$dir"
  git -C "$dir" init -q
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

# repo-alpha: partial plan, Steps 1+3 done, next=Step 2
make_repo "repo-alpha"
add_plan "$SANDBOX/repo-alpha" "feature-x.md" "# Plan: feature-x

## Steps

### Step 1 — First ✅
Done.

### Step 2 — Second
Not done.

### Step 3 — Third ✅
Done.

### Step 4 — Fourth
Not done.

### Step 5 — Fifth
Not done."

# repo-beta: dirty working tree, no plans
make_repo "repo-beta"
echo "uncommitted change" > "$SANDBOX/repo-beta/dirty.txt"

# repo-gamma: complete plan
make_repo "repo-gamma"
add_plan "$SANDBOX/repo-gamma" "done-plan.md" "# Plan: done

## Steps

### Step 1 — Setup ✅
Done.

### Step 2 — Implement ✅
Done.

### Step 3 — Ship ✅
Done."

# not-a-repo: no .git — must be excluded
mkdir -p "$SANDBOX/not-a-repo"
echo "not a repo" > "$SANDBOX/not-a-repo/file.txt"

# --- Run scanner ---

OUTPUT=$("$SCAN_SH" "$SANDBOX")

# --- Assertions ---

echo "=== scan.sh tests ==="
echo ""
echo "--- repo count ---"

REPO_COUNT=$(echo "$OUTPUT" | jq 'length')
assert_eq "3 repos scanned (not-a-repo excluded)" "3" "$REPO_COUNT"

echo ""
echo "--- repo-alpha (partial plan) ---"

ALPHA=$(echo "$OUTPUT" | jq '.[] | select(.name == "repo-alpha")')
assert_eq "alpha: name" "repo-alpha" "$(echo "$ALPHA" | jq -r '.name')"
assert_eq "alpha: dirty=false (all changes committed)" "false" "$(echo "$ALPHA" | jq '.dirty')"
assert_eq "alpha: 1 plan file" "1" "$(echo "$ALPHA" | jq '.plans | length')"

ALPHA_PLAN=$(echo "$ALPHA" | jq '.plans[0]')
assert_eq "alpha: total_steps=5" "5" "$(echo "$ALPHA_PLAN" | jq '.total_steps')"
assert_eq "alpha: completed_steps=2" "2" "$(echo "$ALPHA_PLAN" | jq '.completed_steps')"
assert_eq "alpha: next_step=Step 2 (lowest unmarked)" "Step 2" "$(echo "$ALPHA_PLAN" | jq -r '.next_step')"
assert_eq "alpha: status=in-progress" "in-progress" "$(echo "$ALPHA_PLAN" | jq -r '.status')"
assert_eq "alpha: plan filename" "feature-x.md" "$(echo "$ALPHA_PLAN" | jq -r '.file')"

echo ""
echo "--- repo-beta (dirty, no plans) ---"

BETA=$(echo "$OUTPUT" | jq '.[] | select(.name == "repo-beta")')
assert_eq "beta: dirty=true" "true" "$(echo "$BETA" | jq '.dirty')"
assert_eq "beta: no plans" "0" "$(echo "$BETA" | jq '.plans | length')"
assert_eq "beta: open_prs is array" "array" "$(echo "$BETA" | jq -r '.open_prs | type')"

echo ""
echo "--- repo-gamma (complete plan) ---"

GAMMA=$(echo "$OUTPUT" | jq '.[] | select(.name == "repo-gamma")')
GAMMA_PLAN=$(echo "$GAMMA" | jq '.plans[0]')
assert_eq "gamma: plan total_steps=3" "3" "$(echo "$GAMMA_PLAN" | jq '.total_steps')"
assert_eq "gamma: plan completed_steps=3" "3" "$(echo "$GAMMA_PLAN" | jq '.completed_steps')"
assert_eq "gamma: plan next_step=null" "null" "$(echo "$GAMMA_PLAN" | jq '.next_step')"
assert_eq "gamma: plan status=complete" "complete" "$(echo "$GAMMA_PLAN" | jq -r '.status')"

echo ""
echo "--- JSON structure ---"

FIRST=$(echo "$OUTPUT" | jq '.[0]')
assert_eq "has .name field"     "string" "$(echo "$FIRST" | jq -r '.name | type')"
assert_eq "has .branch field"   "string" "$(echo "$FIRST" | jq -r '.branch | type')"
assert_eq "has .ahead field"    "number" "$(echo "$FIRST" | jq -r '.ahead | type')"
assert_eq "has .behind field"   "number" "$(echo "$FIRST" | jq -r '.behind | type')"
assert_eq "has .dirty field"    "boolean" "$(echo "$FIRST" | jq -r '.dirty | type')"
assert_eq "has .open_prs field" "array"  "$(echo "$FIRST" | jq -r '.open_prs | type')"
assert_eq "has .plans field"    "array"  "$(echo "$FIRST" | jq -r '.plans | type')"

# --- Summary ---

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}All $PASS tests passed.${NC}"
  exit 0
else
  echo -e "${RED}$FAIL of $((PASS + FAIL)) tests failed.${NC}"
  exit 1
fi
