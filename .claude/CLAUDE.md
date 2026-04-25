# Global Development Workflow

## When Plan Mode Is Required

Plan mode is required for substantive implementation work: new features, refactors, multi-file changes, or anything where the approach is non-obvious.

Plan mode is **not** required for:
- One-line fixes, typos, or trivial edits.
- Exploratory questions and code reading.
- Conversational tasks (reviewing this file, drafting a commit message, answering "how does X work").
- Code review follow-up on an already-planned PR.

When in doubt, ask before planning.

## Tone

Write plainly and precisely. No humor, wit, or colloquialisms. Avoid informal expressions like "in anger", "clobber", "nuke", or anything that reads as clever or playful. State facts and decisions directly.

## Effort Levels

Available effort levels (verify against Anthropic docs when a new model releases — see "Keeping this current" below):

- **low** — speed/cost-optimized; classification, lookups, high-volume work.
- **medium** — balanced; solid quality without full token spend.
- **high** — Claude's best on complex reasoning and difficult coding. Default on most models.
- **xhigh** — extended agentic exploration, deep search. **Opus 4.7+ only.** Default on Opus 4.7.
- **max** — highest capability, no token constraints. Session-only unless set via `CLAUDE_CODE_EFFORT_LEVEL`.

Plans MUST pick an effort from this list per step. Use **xhigh** only on models that support it.

**Default when unspecified:** Sonnet / medium for routine implementation; Opus / high for anything ambiguous, novel, or planning-adjacent.

### Keeping this current

When a new Claude model ships (Sonnet 4.7, Opus 4.8, Haiku 5, etc.), check Anthropic's docs and update this section before assigning effort in new plans:

- https://platform.claude.com/docs/en/build-with-claude/effort
- https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-7 (replace version)
- https://code.claude.com/docs/en/model-config

## Planning Rules

- Planning MUST always be done in **Plan mode with Opus**.
- Save plans to `docs/plans/`.
- Every step MUST include:
  - A **Verify** sub-step describing what to run and what passing looks like.
  - The **assigned model** (Opus, Sonnet, or Haiku) and **effort level**.
  - An **effort justification** addressing: (a) ambiguity, (b) unfamiliar third-party internals, (c) compounding-mistake risk, (d) hard-to-verify correctness. Call out close calls.
  - A **context-clear** flag (yes/no): yes when the step starts a logically distinct chapter, or when prior output would be more noise than signal.
  - Which **files** will be modified.
  - Whether the step is **TDD** or **tests-alongside** (see Testing).
- After saving the plan file, **present the filename and wait for confirmation or a new name** before committing.
- After the plan is committed, **always prompt the user to clear context** before implementation begins.

## Multi-Agent Orchestration

When `/multi-agent-plan <plan-file>` is invoked, the orchestrator executes the existing plan — it does **not** create a second plan file. Do not write a new file under `docs/plans/` for the orchestration (no "orchestration plan", no `docs-plans-*-clever-lamport.md`-style companion). Orchestration artifacts (context log, prompts, per-batch results, review, feedback) live under `docs/implementation/<plan-slug>/` only. The input plan file is the single source of truth for scope and steps; the orchestrator reads it, batches steps, and spawns subagents — nothing more gets committed to `docs/plans/`.

## Project Initialization

Before implementation begins:
1. Ensure the directory is a git repository (`git init` if needed).
2. **Ask the user** whether the GitHub repo should be public or private.
3. Create the GitHub repo and push an initial commit with only the plan file.
4. If CI (GitHub Actions) or a test framework are missing, add them as the first implementation step of the plan.
5. Create a feature branch (e.g., `feature/project-name`).

## Implementation Workflow

- **Before executing any plan step**, complete this pre-flight checklist:
  1. **Branch**: On the correct feature branch, not `main`. Never edit code on `main`.
  2. **Infrastructure**: CI and a test framework exist. If not, stop and tell the user.
  3. **Model / effort / context**: See [Model, Effort, and Context Enforcement](#model-effort-and-context-enforcement).
  4. **Prior steps complete**: All previous steps done with verification passed.
  5. **PR status**: If at least one implementation commit has been pushed, the PR exists.
- **One feature branch, one PR, atomic commits per plan step.** Do not split a feature across multiple PRs — if scope is too large, revisit the plan instead.
- Open the PR after the first implementation commit. **Never use draft PRs** — always open a reviewable PR unless explicitly told to use draft mode.
- Each step: implement with tests, verify, commit, push, mark step complete in the plan file, update PR description.

### Commit Messages

Every commit must include:
- A short summary line.
- A body explaining *why* and decisions made.
- Which plan step it corresponds to (e.g., "Step 2a").
- What was verified and how.

### PR Description

- Summary of the plan.
- Checklist of all steps with status (done / in progress / pending).
- Open questions or known issues.
- Update the PR description after each step commit.

### Testing

- A step is not complete until tests covering the new behavior are written and passing.
- If the project lacks a test framework, set one up as the first implementation step of the plan.
- **Tests-first (TDD)** for data transformation, business logic, or mappings: write failing tests, then implement.
- **Tests-alongside** is acceptable for integration wiring, configuration, and structural plumbing.
- Each plan step must declare which mode it uses.

### Verification

- Every step must pass its verification sub-step before committing.
- CI (GitHub Actions) runs linting and tests on every push to the PR.
- Mark each completed step by appending `✅` to the step's heading line in the plan file. A plan with all steps checkmarked is considered complete; the `/work-log` skill relies on this.

### When Verification Fails

1. **Diagnose first** — do not retry blindly. Identify root cause.
2. **Fix in place** if the failure is a small implementation bug within the step's scope.
3. **Pause and re-plan** if the failure reveals the step itself is wrong (bad assumption, missing dependency, wrong approach). Update the plan file before continuing — see Plan Revisions.
4. Never suppress a failing test, skip CI, or commit `--no-verify` to make the failure go away.

### Plan Revisions

When implementation reveals the plan is wrong:
1. Stop the current step.
2. Edit the plan file to reflect the new approach. Mark superseded steps as obsolete (don't delete — leave them for context).
3. Show the user the diff and wait for confirmation before resuming.
4. Commit the plan revision separately from any implementation changes.

## Model, Effort, and Context Enforcement

Each plan step has an assigned model, an effort level, and a context-clear flag. Before starting a step, evaluate all three:

- **Model or effort changed** → stop, announce the change, wait for the user to confirm (and switch models if needed).
- **Context-clear is yes** → stop, prompt the user to clear context, then wait for confirmation. Applies even if model and effort are unchanged.
- **All three unchanged** → continue without interruption.

When announcing a pause, **bold** the model name and effort level (e.g., "still **Sonnet / medium**" or "next step requires **Opus / max**"). If a context clear is needed, state it alongside the assignment.

**Steps MUST be executed in strict sequential order.** Never skip ahead while an earlier step is incomplete.

## Code Review Follow-up

When a code review produces actionable improvements (Opus review, PR comments, etc.):
1. Implement the changes on the same feature branch.
2. Update or add tests as needed.
3. Verify (type check + tests pass).
4. **Initiate the commit flow without waiting to be asked** — follows the standard commit workflow, with the message referencing the review.

## Post-Merge Cleanup

When the user says they have merged the PR:
1. `git checkout main`
2. `git pull`
3. `git branch -d <feature-branch>`
4. If the PR completed a plan (all steps marked ✅), move the plan file from `docs/plans/` to `docs/plans/archive/`. Create the archive directory if needed. Commit the move on main.

## Git Hygiene

- `.claude/settings.local.json` must never be committed. Always ensure it is in `.gitignore`.
- **Never commit secrets or credentials** — `.env`, `*.pem`, `*.key`, API tokens, OAuth client secrets. If you suspect a secret was committed, stop and tell the user immediately.
- **Lockfiles are committed** (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Gemfile.lock`, etc.) unless the project explicitly says otherwise.
- **Don't commit generated files** (build artifacts, `dist/`, `.next/`, coverage reports) unless the project's `.gitignore` shows they're intentionally tracked.

## Dependencies

Adding new packages is OK without prior approval — but **call it out in the response and the commit message** when you do, so it shows up in review. Note the package name, what it's for, and whether it's a runtime or dev dependency. If a package introduces a notable license, large transitive tree, or replaces something already in the project, surface that explicitly before installing.

## Retrospective Loop

User Context is imported from `~/.claude/user-context.md`, which is auto-generated by `retro --run` (in the `command-center` repo) and replaced in full on every retro run. The file is intentionally untracked (it contains personal/work details) — do not edit it manually, and do not check it into any repo. The retro analyzes recent Claude Code sessions and updates work/personal/history context. If User Context looks stale, suggest running `retro --run` rather than hand-editing.

## iCloud Markdown Notes (MCP Server)

The `markdown-notes-mcp` MCP server provides access to markdown files in iCloud Drive:

- **projects** (read-only): `/Users/rodmachen/Library/Mobile Documents/com~apple~CloudDocs/folio/projects`
- **markdown-notes** (writable): `/Users/rodmachen/Library/Mobile Documents/com~apple~CloudDocs/folio/markdown-notes`

Use the MCP tools (`list_directories`, `list_files`, `read_file`, `search_files`, `save_file`, `delete_file`, `move_file`) to interact with these notes.

### Save Behavior

- **Proactive offers:** When producing substantial output (analysis, summary, plan, reference material), offer: "Want me to save this to your notes?" Never write without user confirmation.
- **Before saving:** Call `list_directories` on `markdown-notes` to see existing subfolder structure. Slot into an existing folder when the topic fits; create a new subfolder only when nothing matches.
- **Propose the full path** and wait for confirmation before writing: "I'd save this to `coding/mcp-architecture-notes.md` — sound good?"
- **Append to existing files** when the topic is recurring. Use `search_files` to find the existing file first, then `save_file` with `mode: "append"`. The server auto-adds a `## YYYY-MM-DD` date heading.
- **Create new files** for one-off analyses, plans, or distinct topics.
- **Never overwrite** without explicit user request.

### Naming Conventions

- **Filenames:** `descriptive-slug.md` — lowercase kebab-case, max ~5 words in slug. No date prefix.
- **Date metadata:** Always prepend two lines at the top of file content (before any heading): `Generated: Month DD, YYYY` (date response was generated) and `Saved: Month DD, YYYY` (today's date).
- **Subfolders:** lowercase kebab-case topic names (e.g., `job-search/`, `coding/`, `french/`). Max 2 levels deep. Created organically on first save — do not pre-create empty folders.
- **Reserved:** `daily-briefings/` is managed by Command Center — never save responses there.
- For detailed conventions and examples, read `markdown-notes/CONVENTIONS.md` via the MCP server.

### Cleanup Workflow

When asked to reorganize: call `list_directories` + `list_files` to audit structure, propose changes (merges, renames, deletes) as a list, confirm each with user, then execute with `move_file`/`delete_file`.

## Work Log Notes

The `/work-log` skill maintains per-repo state files at `~/Library/Mobile Documents/com~apple~CloudDocs/folio/markdown-notes/work-log/repos/<repo>.md`. When Rod asks to "add a note to <repo>" or "remember <X> for <repo>", append the text to the `## User notes` section of the repo file. Never modify other sections (`Current state`, `Active plans`, `Completed plans`) — those are skill-managed. Append, don't replace. Use a bullet list; one idea per line. When a user-note line mentions a plan filename and that plan is no longer in "not started" state, surface the line for removal rather than silently deleting.

@~/.claude/user-context.md
