# Plan: example-hygiene

A fixture representing a hygiene case: PR was merged, but Step 3 never got its ✅ mark.
The parser itself reports "in-progress"; the hygiene layer combines this with PR state
(merged commit message referencing this filename) to surface it for cleanup.

## Context

Synthetic test fixture. Expected parse (from file alone): 5 steps total, 4 complete, next_step="Step 3", status=in-progress.

The hygiene warning is raised externally when: PR referencing `plan-hygiene.md` is merged
AND the parse reports status=in-progress.

## Steps

### Step 1 — Setup ✅
Done.

### Step 2 — Bootstrap ✅
Done.

### Step 3 — Core logic
Actually done in code, but user forgot to append ✅. This is what hygiene catches.

### Step 4 — Helper ✅
Done.

### Step 5 — Ship ✅
Done.
