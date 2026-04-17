---
name: work-log
description: "Produces a ranked daily queue of actionable work across Rod's active repos in ~/code/. Manages per-repo state files in iCloud (markdown-notes/work-log/repos/) and surfaces hygiene warnings. Invoke with /work-log (queue), /work-log refresh (force), /work-log init <repo> (bootstrap), or /work-log note <repo> <text> (append user note)."
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__markdown-notes__list_files, mcp__markdown-notes__read_file, mcp__markdown-notes__save_file, mcp__markdown-notes__search_files
argument-hint: "[refresh | init <repo> | note <repo> <text>]"
---

# /work-log — Cross-Repo Work Queue

You produce a ranked daily queue of actionable work across Rod's active repositories in `~/code/`. The queue is backed by per-repo state files in iCloud that also serve as the memory layer — no separate memory store.

## Parse the argument first

`$ARGUMENTS` determines which sub-command runs:

| Argument shape | Sub-command |
|---|---|
| empty | **queue** — lazy-refresh if stale, then render `_current.md` |
| `refresh` | **refresh** — force full rescan, bypass mtime check |
| `init <repo>` | **init** — bootstrap one repo's state file from git + plan history |
| `note <repo> <text...>` | **note** — append a bullet to the repo's `## User notes` section |

If `$ARGUMENTS` does not match one of the patterns above, show the user the argument-hint and stop.

---

## Paths (resolve once at start)

- **iCloud work-log root:** `~/Library/Mobile Documents/com~apple~CloudDocs/markdown-notes/work-log/`
- **Repo state files:** `<root>/repos/<repo-name>.md`
- **Current queue:** `<root>/_current.md`
- **Archive:** `<root>/archive/YYYY-MM-DD.md`
- **Code root:** `~/code/`
- **Scanner:** `~/.claude/skills/work-log/scan.sh` (Step 3 deliverable; falls back to inline git if missing)

Use the **markdown-notes MCP** for all iCloud writes (it handles locking and path escaping). Use **Bash** for local git/gh work and for reading files under `~/.claude/skills/`.

---

## Plan-file parsing rules

Authoritative for every sub-command that touches plan files.

### Step heading regex
- **Step heading:** `^#{2,}\s+Step\s+(\d+)` (matches `## Step N`, `### Step N`, etc.) — capture the integer as the step number.
- The heading line runs from the first `#` to the newline.
- Non-step headings (Context, Design summary, Verification, etc.) are ignored.

### Completion detection
- A step is **complete** if its heading line ends with `✅` (optionally followed by whitespace).
- A heading that contains `✅` mid-line but not at the end does NOT count as complete.
- Case matters: the emoji is literally `✅` (U+2705). Do not accept `✓`, `✔`, `[x]`, or text like `**done**` — those trigger a hygiene warning instead.

### Derived fields (per plan file)
- `total_steps` — count of matched Step headings.
- `completed_steps` — count of matched Step headings ending with `✅`.
- `next_step` — the label (`Step N`) of the **lowest-numbered** step whose heading is not marked complete; `null` if all complete. Order by the captured integer, not file position.
- `status` —
  - `complete` if `completed_steps == total_steps` and `total_steps > 0`
  - `not-started` if `completed_steps == 0`
  - `in-progress` otherwise

Sanity: if `total_steps == 0`, treat the file as a draft (surface under "pre-plans — promote or discard"); do not emit a status.

---

## Inclusion rule (which repos appear in the queue)

A repo at `~/code/<name>/` is included if **any** of:

1. Has a plan file under `docs/plans/*.md` with status `in-progress` or `not-started`.
2. Has at least one open PR (`gh pr list --state open --json number`).
3. Working tree is dirty (`git status --porcelain`).
4. Local branch is ahead of `origin/<branch>` (`git rev-list --count origin/<branch>..HEAD`).
5. A state file exists at `<root>/repos/<name>.md` and its `## User notes` section is non-empty.

Repos that are git repos but meet none of the above are silent (not rendered).

---

## Ranking rubric v1

Assign each actionable item a score; rank by score descending. Ties broken by recency of last-touched commit.

| Signal | Weight | Rationale |
|---|---|---|
| Unblocks a queued repo (user-note mentions "blocked on <repo>" elsewhere) | +10 | Finishing blockers is highest-leverage work |
| Plan has 1–2 steps remaining | +7 | Finish-momentum bias; small completions build state |
| Commits ahead of origin (ready-to-ship) | +6 | Lowest-friction path to green |
| Stale in-progress (>7 days since last commit on plan branch) | +4 | Needs a decision: resume or shelve |
| Open PR awaiting user action | +5 | Blocked on Rod — quickest unblock |
| Plan ready, not started | +2 | Baseline "available work" |
| User-note phrase "next up" or "high priority" | +3 | Explicit user signal |
| User-note phrase "back-burner" or "queued" | -5 | Explicit deprioritization |
| Hygiene case (PR merged, steps not all ✅) | — | Surfaced in a separate section; not ranked |
| Pre-plan (draft, 0 Step headings) | +1 | Promote or discard — low signal alone |

Apply weights additively. A repo with multiple actionable items contributes each one separately to the queue.

**Tuning note:** These weights are v1. Step 5 revisits them after real-world use; do not tune unless explicitly asked.

---

## Output template (queue sub-command)

Render `_current.md` with this structure. Keep it scannable in <30 seconds.

```markdown
# Work log — YYYY-MM-DD

## Top picks

1. **<repo>** — <next-step> (<1-line why>)
2. **<repo>** — <next-step> (<1-line why>)
3. **<repo>** — <next-step> (<1-line why>)

## By state

### Ready to ship
- **<repo>** — N commits ahead of origin

### In progress
- **<repo>** — <plan.md>, N/M steps, next: Step X (<title>)

### Plans ready, not started
- **<repo>** — <plan.md>, M steps

### Open PRs
- **<repo>** — #N <title> (<mergeable>)

### Hygiene
- **<repo>** — <plan.md>: PR #N merged but Step X not marked ✅. Clean up?
- **<repo>** — user-note mentions <plan.md> which is now in-progress. Remove note?

### Pre-plans
- **<repo>** — <draft.md> (no Step headings yet)

## All tracked repos

| Repo | State | Plan | Progress | Next | Notes |
|---|---|---|---|---|---|
| ... | ... | ... | N/M | Step X | Step 2 done 8d ago |
```

Replace `<root>/_current.md` with the rendered output. If a dated snapshot for today (`archive/YYYY-MM-DD.md`) exists, overwrite it; otherwise create it.

---

## Lazy refresh

On the **queue** sub-command (empty `$ARGUMENTS`):

1. Compute the "start of today" as 06:00 America/Chicago.
2. Stat `<root>/_current.md`. If mtime ≥ start-of-today, just print `_current.md` contents and stop. (Fast path.)
3. Otherwise, run a full refresh:
   a. Call `scan.sh` (if present) to collect per-repo facts as JSON. If absent, loop over `~/code/*/` with inline `git` + `gh` commands.
   b. For each included repo, ensure `<root>/repos/<name>.md` exists; if not, create it via the init procedure. Update the skill-managed sections (Current state, Active plans, Completed plans). **Never touch the `## User notes` section.**
   c. Rank items using the rubric above.
   d. Render the queue to `_current.md` via `mcp__markdown-notes__save_file` with `mode: "overwrite"`.
   e. Also write `archive/YYYY-MM-DD.md` (same content; overwrite allowed — one entry per day).

The `refresh` sub-command skips step 2 and always runs step 3.

---

## Archive behavior

- One file per day: `archive/YYYY-MM-DD.md`.
- Multiple refreshes on the same day overwrite that date's snapshot (append is wrong — the queue is a point-in-time view, not a log).
- Archive is append-only across days; never delete past snapshots.

---

## `init <repo>` sub-command

Bootstrap `<root>/repos/<repo>.md` from git + plan-file history.

1. Resolve `~/code/<repo>/`. Fail if not a git repo.
2. Collect:
   - Current branch and clean/dirty state.
   - Last merged PR (`gh pr list --state merged --limit 1 --json number,title,mergedAt`).
   - Open PRs.
   - All plan files under `docs/plans/*.md`; parse each using the rules above.
3. If the state file already exists, **preserve its `## User notes` section verbatim**. Rewrite only the skill-managed sections.
4. Write using this template:

```markdown
# <repo>
_Last updated by /work-log: YYYY-MM-DD_

## Current state
- Branch: <branch> (<clean|dirty>)
- Last merged: PR #<n> — <title> (<YYYY-MM-DD>)
- Open PRs: <list or "none">

## Active plans
- <file> — <status>, <completed>/<total> steps, next: <next_step or "—">

## Completed plans
- <file> — ✅ (<PR ref if known>)

## User notes
<preserved verbatim; empty on first init>
```

5. Save via `mcp__markdown-notes__save_file`:
   - First init: `mode: "create"`.
   - Re-init: `mode: "overwrite"` **only after** reading the existing file and capturing `## User notes` to re-insert.

---

## `note <repo> <text...>` sub-command

Append a bullet to `<root>/repos/<repo>.md` under `## User notes`.

1. Read the current file via `mcp__markdown-notes__read_file`. If missing, instruct the user to run `/work-log init <repo>` first.
2. Locate the `## User notes` heading.
3. Append `- <text>` on a new line at the end of that section (before the next heading or EOF).
4. **Do not touch any other section.** Specifically, never rewrite `## Current state`, `## Active plans`, or `## Completed plans`.
5. Save with `mode: "overwrite"`.

Natural-language entry is also valid: if Rod says "add a note to <repo>: <text>", use the same logic. The `/work-log note` form is just the explicit path.

---

## Hygiene detection

Raise hygiene items during the queue-refresh pass (not during `init`):

- **Plan-marked-as-unmarked.** For each plan file whose status is `in-progress`, check git log for a merge commit that references the filename (`git log --all --oneline -- docs/plans/<file>`). If a PR referencing the file was merged and the plan is not `complete`, emit: `<repo> — <file>: PR #N merged but not all steps marked ✅. Clean up?`
- **Stale linked note.** For each `## User notes` bullet across all repo state files, extract any `*.md` filename references. If the referenced plan's status is no longer `not-started` (i.e., has moved on), emit: `<repo> — user-note mentions <file> which is now <status>. Remove this note?`

Hygiene items are **always shown to the user** for action — never auto-deleted or auto-resolved. Show them in the `### Hygiene` section of the output.

---

## Error handling

- **iCloud sync delay.** If `mcp__markdown-notes__read_file` returns "not found" for a file you expect to exist, wait briefly (≤2s) and retry once. If still missing, treat as absent and create.
- **gh not authenticated.** If `gh pr list` fails with auth error, degrade gracefully: skip PR signals, note "gh unavailable" in the output, continue with git-only signals.
- **Repo with no remote.** Skip ahead/behind checks; treat as local-only. Still honor other inclusion signals.
- **scan.sh missing.** Log once, fall back to inline git. Do not fail the run.

---

## Constraints

- Never modify files under `~/code/` as part of a queue render or note append. The skill is read-only with respect to project repos.
- Never modify `## User notes` sections on the user's behalf except:
  - Appending via the `note` sub-command.
  - Surfacing a hygiene-flag removal suggestion for the user to confirm.
- Keep `_current.md` under ~200 lines when rendered. If the queue would be longer, collapse "All tracked repos" and show only "Top picks" + "By state".

---

## Reference: test fixtures

`~/.claude/skills/work-log/tests/fixtures/plan-*.md` with matching `tests/expected/*.json` document the parser contract. Any change to the parsing rules above MUST be reflected in the fixtures and expected outputs.

| Fixture | total | completed | next_step | status |
|---|---|---|---|---|
| `plan-complete.md` | 3 | 3 | `null` | complete |
| `plan-partial.md` | 7 | 3 | Step 3 | in-progress |
| `plan-unstarted.md` | 4 | 0 | Step 1 | not-started |
| `plan-hygiene.md` | 5 | 4 | Step 3 | in-progress |
