# /multi-agent-plan

Execute a multi-agent development workflow from a plan document to a fully implemented, reviewed, and updated PR — without interruption.

## Invocation
```
/multi-agent-plan <path-to-plan.md>
```

Run this command from inside the same repo where the plan document lives. All file paths are relative to the project root, and the permission sandbox is scoped there.

---

## Your Role: Orchestrator

You are the orchestrator for the full run. You coordinate the pipeline, manage shared context, compose Task prompts, and drive execution from start to finish. You do not implement anything directly — all execution happens via `claude` subprocesses invoked through bash.

**Recommended setup for the orchestrator session**: Opus 4.7 at xhigh effort. This is the correct level for coordination, judgment calls, blocker evaluation, and prompt composition. On Opus 4.7, xhigh is the default — no manual configuration needed.

---

## How Subagents Work

Spawn subagents by shelling out to `claude` via bash:

```bash
claude --model {model} \
  --effort {effort} \
  --allowedTools "{tool-list}" \
  -p "$(cat docs/implementation/{plan-name}/prompts/step-N.md)" \
  --output-format json > docs/implementation/{plan-name}/results/step-N.json
```

### Model Tiers

All three tiers are valid. Respect whatever tier the plan tags each step with:

| Tier | Flag | Use for |
|---|---|---|
| Opus | `--model opus` | Architecture decisions, complex debugging, review pass |
| Sonnet | `--model sonnet` | Standard implementation, most coding tasks, feedback pass |
| Haiku | `--model haiku` | Mechanical work: file lookups, simple transforms, grep-and-replace, deterministic outputs requiring no judgment |

### Effort Levels

Effort applies to Opus and Sonnet only. Haiku has no effort configuration — omit `--effort` entirely for Haiku subagents.

| Model | Valid levels | Default |
|---|---|---|
| Opus 4.7 | `low`, `medium`, `high`, `xhigh`, `max` | `xhigh` |
| Sonnet 4.6 | `low`, `medium`, `high`, `max` | `high` |
| Haiku 4.5 | none | n/a — fixed capability |

Use `--effort` as a CLI flag on the subprocess invocation:

```bash
# Sonnet at high effort
claude --model sonnet --effort high --allowedTools "Bash,Write,Edit,Read" -p "..."

# Haiku — no effort flag
claude --model haiku --allowedTools "Bash,Read" -p "..."
```

### Batching Key

Batch consecutive steps that share the **same model AND the same effort level**. A difference in either model or effort is a split point — spawn a separate subprocess. This is the most common split between Sonnet/medium and Sonnet/high, or Opus/high and Opus/xhigh.

### Allowed Tools Per Agent Type

Always specify `--allowedTools` explicitly. Subagents cannot respond to interactive permission prompts in `-p` mode — unspecified tool calls will silently fail.

| Agent Type | `--allowedTools` |
|---|---|
| Implementation (Sonnet/Haiku) | `"Bash,Write,Edit,Read"` |
| Opus task | `"Bash,Read,Write"` |
| Review | `"Bash,Read,Write"` |
| Feedback | `"Bash,Write,Edit,Read"` |

---

## Phase 0: Directory Setup

Extract plan name from filename (strip `.md`). Create:

```
docs/implementation/{plan-name}/
  context.md          ← running log of decisions, results, assumptions, blockers
  review.md           ← populated by Review Agent
  feedback-report.md  ← populated by Feedback Agent
  prompts/            ← one .md file per step/batch, written before execution
  results/            ← one .json file per step/batch, written by subagents
```

Write a header to `context.md` with the plan name, start time, and a one-paragraph summary of what the plan accomplishes.

---

## Phase 1: Parse and Tag

Read the plan in full. For each step, identify:
- **Model**: `haiku`, `sonnet`, or `opus`
- **Effort**: as tagged in the plan (`low`, `medium`, `high`, `xhigh`). If the plan does not tag effort, default to `high` for Sonnet and `xhigh` for Opus.
- **Dependencies**: which prior steps this step needs results from
- **Success criteria**: how you'll verify the step completed correctly

Write the full tagged step list to `context.md` under `## Plan`.

> **Note for planning**: When Opus 4.7 generates the plan, ensure it is aware of the full effort scale. Valid levels are: Opus 4.7 — `low`, `medium`, `high`, `xhigh` (default), `max`; Sonnet 4.6 — `low`, `medium`, `high`, `max`; Haiku — none.

---

## Phase 2: Batch

Group consecutive steps that share the same model **and** the same effort level into a single batch. Each batch = one subagent invocation.

Only split a batch further if there is a conditional branch between steps that you must evaluate before deciding how to proceed.

---

## Phase 3: Execution Loop

For each batch:

1. **Create a Task** using `TaskCreate` with subject, description, and `metadata: { model, effort, steps }`. Use `addBlockedBy` to wire in any dependency on a prior task's ID.

2. **Write the prompt** for this batch to `prompts/step-N.md`. Include:
   - The step(s) to execute
   - Relevant context pulled from `context.md` and prior `results/` files
   - Explicit success criteria
   - Instruction: *"Write your results, decisions, and assumptions as a JSON object to the path specified. Do not ask for confirmation — execute directly."*

3. **Update the Task** to `in_progress`.

4. **Spawn the subagent** via bash with the appropriate `--model`, `--effort` (if applicable), and `--allowedTools` flags.

5. **Parse the result** from `results/step-N.json`. Verify success criteria are met. Append a summary to `context.md` under the step heading.

6. **Update the Task** to `completed` (or handle failure — see below).

---

## Phase 4: Review Agent

After all execution batches complete:

1. **Write `prompts/review.md`** with:
   - The full PR diff (output of `git diff main`)
   - The full contents of `context.md`
   - Instruction: *"Review these changes. For each issue found, output a JSON array where each item has: `severity` (`blocking` or `non-blocking`), `location` (file and line if applicable), `description` (what the issue is), and `suggestion` (recommended fix). Write the array to the path specified."*

2. **Create a Review Task**, then spawn an Opus subagent at xhigh effort:

```bash
claude --model opus --effort xhigh \
  --allowedTools "Bash,Read,Write" \
  -p "$(cat docs/implementation/{plan-name}/prompts/review.md)" \
  --output-format json > docs/implementation/{plan-name}/results/review.json
```

3. **Parse `results/review.json`** and write a human-readable summary to `review.md`.

Each review item must include:
- `severity`: `blocking` or `non-blocking`
- `location`: file and line if applicable
- `description`: what the issue is
- `suggestion`: recommended fix

---

## Phase 5: Feedback Agent

1. **Write `prompts/feedback.md`** with:
   - The full contents of `review.md`
   - The relevant source files identified in the review items
   - Instruction: *"Address every `blocking` review item. Address `non-blocking` items with best judgment; defer only with a clear reason. Write a feedback-report.md to the path specified listing: what was changed, what was deferred and why, and any new issues surfaced during fixes. Do not ask for confirmation — execute directly."*

2. **Create a Feedback Task**, then spawn a Sonnet subagent at high effort:

```bash
claude --model sonnet --effort high \
  --allowedTools "Bash,Write,Edit,Read" \
  -p "$(cat docs/implementation/{plan-name}/prompts/feedback.md)" \
  --output-format json > docs/implementation/{plan-name}/results/feedback.json
```

3. **Parse `results/feedback.json`** and confirm `feedback-report.md` was written.

---

## Phase 6: Final Check

Read `feedback-report.md`. Verify no unresolved `blocking` items remain. Update all Tasks to `completed`. Write a completion summary to `context.md` under `## Completion`.

---

## Never Stop Unless

Only halt and surface to the user when you hit a genuine hard blocker:

| Category | Example |
|---|---|
| **Missing credentials** | Required API key, token, or env var not present in the repo or environment |
| **Unresolvable merge conflict** | Conflicts that require human judgment about intent, not just mechanics |
| **Fundamentally underspecified step** | Ambiguity that would invalidate *subsequent* steps if you guess wrong — not just this one |
| **Cascading subagent failure** | A subagent failed; a retry with a revised prompt also failed |
| **Irreversible destructive action** | The plan requires dropping tables, deleting data, or other permanent operations not explicitly authorized |

For everything else: make your best judgment, log the assumption in `context.md` under `## Assumptions`, and continue.

When you do halt on a hard blocker, before surfacing to the user write a stop summary to `context.md` under `## Stopped` that includes: what completed successfully, which step failed, why it qualifies as a hard blocker, and what the user would need to resolve to continue.

---

## Error Handling

- If a subagent exits non-zero or returns malformed output, retry **once** with a revised prompt that addresses the likely failure reason
- If it fails again, log it under `## Blockers` in `context.md`, evaluate against the hard blocker list, and write a stop summary if halting
- If a step's dependency failed, update its Task to `completed` with subject `"Skipped — blocked by failed dependency: {step}"` and log the full explanation in `context.md`; do not delete the Task
- Never ask the user for clarification during execution
