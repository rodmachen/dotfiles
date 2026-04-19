#!/usr/bin/env bash
# scan.sh — scan git repos under DIR and emit JSON work-log data
# Usage: scan.sh [DIR [REPO_FILTER]]
# Output: JSON array, one object per git repo found in DIR's immediate children
#   { name, branch, ahead, behind, dirty, dirty_count, open_prs, plans[], archives }
# Each plans[] element: { file, total_steps, completed_steps, next_step, status }
# archives: { moved:[{file,date},...], skipped:[{file,reason},...] }
# Requires: git, jq, python3; gh is optional (degrades gracefully)

set -uo pipefail

SCAN_DIR="${1:-$HOME/code}"
FILTER="${2:-}"

# Parse a plan file and emit a JSON object via Python (handles UTF-8 ✅ correctly)
parse_plan() {
  local file="$1"
  python3 - "$file" <<'PYEOF'
import sys, json, re

path = sys.argv[1]
try:
    content = open(path, encoding="utf-8", errors="replace").read()
except Exception:
    sys.exit(0)

heading_re = re.compile(r'^#{2,}\s+Step\s+(\d+)(.*)', re.MULTILINE)
matches = list(heading_re.finditer(content))

total = len(matches)
completed_nums = set()
all_nums = []

for m in matches:
    num = int(m.group(1))
    all_nums.append(num)
    # Complete iff the full heading line ends with ✅ (optional trailing whitespace)
    if re.search(r'✅\s*$', m.group(0)):
        completed_nums.add(num)

completed = len(completed_nums)
all_sorted = sorted(set(all_nums))
incomplete = [n for n in all_sorted if n not in completed_nums]
next_step = f"Step {incomplete[0]}" if incomplete else None

if total == 0:
    status = "draft"
elif completed == total:
    status = "complete"
elif completed == 0:
    status = "not-started"
else:
    status = "in-progress"

print(json.dumps({
    "file": path.split("/")[-1],
    "total_steps": total,
    "completed_steps": completed,
    "next_step": next_step,
    "status": status
}))
PYEOF
}

# Return a JSON array of parsed plan objects for all plan files in REPO_DIR
collect_plans() {
  local repo_dir="$1"
  local plans_dir="$repo_dir/docs/plans"
  local results=()

  if [[ -d "$plans_dir" ]]; then
    while IFS= read -r -d '' plan_file; do
      local parsed
      parsed=$(parse_plan "$plan_file") || continue
      [[ -n "$parsed" ]] && results+=("$parsed")
    done < <(find "$plans_dir" -maxdepth 1 -name "*.md" -print0 2>/dev/null | sort -z)
  fi

  if [[ ${#results[@]} -eq 0 ]]; then
    echo '[]'
  else
    printf '%s\n' "${results[@]}" | jq -s '.'
  fi
}

# Emit one filename per line for plan files whose parsed status is "complete".
detect_complete_plans() {
  local repo_dir="$1"
  local plans_dir="$repo_dir/docs/plans"
  [[ -d "$plans_dir" ]] || return 0

  while IFS= read -r -d '' plan_file; do
    local parsed status
    parsed=$(parse_plan "$plan_file") || continue
    [[ -z "$parsed" ]] && continue
    status=$(printf '%s' "$parsed" | jq -r '.status // "unknown"' 2>/dev/null)
    if [[ "$status" == "complete" ]]; then
      basename "$plan_file"
    fi
  done < <(find "$plans_dir" -maxdepth 1 -name "*.md" -print0 2>/dev/null | sort -z)
}

# Archive newly-complete plans in the given repo under docs/plans/archive/.
# Args: repo_dir, branch, pre_archive_dirty_porcelain
# Guardrails: skip if on main/master; skip if plan file is dirty pre-archive;
#             skip if archive target already exists.
# Honors WORKLOG_DRYRUN=1 (records intent; no disk writes).
# Output: JSON object {moved:[...], skipped:[...]}
archive_complete_plans() {
  local repo_dir="$1"
  local branch="$2"
  local pre_dirty_files="$3"

  local today
  today=$(date +%Y-%m-%d)

  # Whether the repo is on a protected branch (constant for this invocation)
  local on_protected=false
  [[ "$branch" == "main" || "$branch" == "master" ]] && on_protected=true

  local moved_entries=() skipped_entries=()

  while IFS= read -r plan_name; do
    [[ -z "$plan_name" ]] && continue

    # Guardrail 1: repo is on main/master — don't commit-adjacent writes silently
    if [[ "$on_protected" == "true" ]]; then
      skipped_entries+=("$(jq -n --arg file "$plan_name" --arg reason "on $branch" \
        '{file:$file, reason:$reason}')")
      continue
    fi

    # Guardrail 2: plan file has pending changes — don't mix user edits with rename
    # Use full-line matching (awk strips the 2-char porcelain status prefix + space)
    if printf '%s\n' "$pre_dirty_files" | awk '{print substr($0,4)}' | grep -qxF "docs/plans/$plan_name"; then
      skipped_entries+=("$(jq -n --arg file "$plan_name" \
        '{file:$file, reason:"dirty working tree for plan file"}')")
      continue
    fi

    # Guardrail 3: archive target already exists — avoid clobbering
    if [[ -e "$repo_dir/docs/plans/archive/$plan_name" ]]; then
      skipped_entries+=("$(jq -n --arg file "$plan_name" \
        '{file:$file, reason:"archive target already exists"}')")
      continue
    fi

    if [[ "${WORKLOG_DRYRUN:-0}" == "1" ]]; then
      moved_entries+=("$(jq -n --arg file "$plan_name" --arg date "$today" --argjson dryrun true \
        '{file:$file, date:$date, dryrun:$dryrun}')")
    else
      mkdir -p "$repo_dir/docs/plans/archive"
      if git -C "$repo_dir" mv "docs/plans/$plan_name" "docs/plans/archive/$plan_name" 2>/dev/null; then
        moved_entries+=("$(jq -n --arg file "$plan_name" --arg date "$today" \
          '{file:$file, date:$date}')")
      else
        skipped_entries+=("$(jq -n --arg file "$plan_name" \
          '{file:$file, reason:"git mv failed"}')")
      fi
    fi
  done < <(detect_complete_plans "$repo_dir")

  local moved_json skipped_json
  if [[ ${#moved_entries[@]} -eq 0 ]]; then
    moved_json='[]'
  else
    moved_json=$(printf '%s\n' "${moved_entries[@]}" | jq -s '.')
  fi
  if [[ ${#skipped_entries[@]} -eq 0 ]]; then
    skipped_json='[]'
  else
    skipped_json=$(printf '%s\n' "${skipped_entries[@]}" | jq -s '.')
  fi

  jq -n --argjson moved "$moved_json" --argjson skipped "$skipped_json" \
    '{moved:$moved, skipped:$skipped}'
}

# Scan a single repo directory and print a JSON object (or nothing if filtered)
scan_repo() {
  local dir="$1"
  local name
  name=$(basename "$dir")

  [[ -n "$FILTER" && "$name" != "$FILTER" ]] && return 0

  # Branch
  local branch
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="unknown"

  # Ahead/behind relative to tracking branch (0 if no remote)
  local tracking ahead behind
  tracking=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null) || tracking=""
  if [[ -n "$tracking" ]]; then
    ahead=$(git -C "$dir"  rev-list --count "${tracking}..HEAD" 2>/dev/null)  || ahead=0
    behind=$(git -C "$dir" rev-list --count "HEAD..${tracking}" 2>/dev/null) || behind=0
  else
    ahead=0
    behind=0
  fi

  # Dirty porcelain snapshot taken BEFORE archival — used for archive guardrails.
  # The emitted dirty/dirty_count are re-computed AFTER archival to reflect any
  # staged renames scan.sh itself introduced.
  local pre_dirty_files
  pre_dirty_files=$(git -C "$dir" status --porcelain 2>/dev/null)

  # Archive complete plans (may stage git mv renames in the working tree)
  local archives_json
  archives_json=$(archive_complete_plans "$dir" "$branch" "$pre_dirty_files")

  # Post-archive dirty flag + count
  local dirty_files dirty dirty_count
  dirty_files=$(git -C "$dir" status --porcelain 2>/dev/null)
  if [[ -n "$dirty_files" ]]; then
    dirty=true
    dirty_count=$(printf '%s\n' "$dirty_files" | wc -l | tr -d ' ')
  else
    dirty=false
    dirty_count=0
  fi

  # Open PRs (gh optional; empty array on any failure)
  local open_prs
  open_prs=$(cd "$dir" && gh pr list --state open --json number,title 2>/dev/null) || open_prs='[]'
  # Validate JSON array; reset to [] if gh returned garbage
  if ! printf '%s' "$open_prs" | jq -e 'type == "array"' >/dev/null 2>&1; then
    open_prs='[]'
  fi

  # Plans — archived ones are naturally excluded (find uses maxdepth 1)
  local plans_json
  plans_json=$(collect_plans "$dir")

  jq -n \
    --arg     name        "$name"        \
    --arg     branch      "$branch"      \
    --argjson ahead       "$ahead"       \
    --argjson behind      "$behind"      \
    --argjson dirty       "$dirty"       \
    --argjson dirty_count "$dirty_count" \
    --argjson open_prs    "$open_prs"    \
    --argjson plans       "$plans_json"  \
    --argjson archives    "$archives_json" \
    '{name:$name, branch:$branch, ahead:$ahead, behind:$behind,
      dirty:$dirty, dirty_count:$dirty_count, open_prs:$open_prs,
      plans:$plans, archives:$archives}'
}

main() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064 — intentional: expand $tmpdir now so trap works after main() returns
  trap "rm -rf '$tmpdir'" EXIT

  local repo_dirs=()
  for dir in "$SCAN_DIR"/*/; do
    dir="${dir%/}"
    [[ -d "$dir/.git" ]] || continue
    repo_dirs+=("$dir")
    # Run each repo scan in parallel; write JSON to a temp file
    (scan_repo "$dir" > "$tmpdir/$(basename "$dir").json" 2>/dev/null) &
  done

  # Wait for all background scans
  wait

  # Collect results in original order
  local results=()
  for dir in "${repo_dirs[@]}"; do
    local f="$tmpdir/$(basename "$dir").json"
    [[ -s "$f" ]] && results+=("$(cat "$f")")
  done

  if [[ ${#results[@]} -eq 0 ]]; then
    echo '[]'
  else
    printf '%s\n' "${results[@]}" | jq -s '.'
  fi
}

main
