# Plan → Execute Workflow — Operator Guide

Full reference for the `Plan → Execute Workflow` Goose Desktop Notebook.
For command reference see `docs/operations.md`. For failures see `docs/troubleshooting.md`.

## Overview

The workflow loop: `(00 List) → 01 | 01b → 02 → 03 → 04 → 05 → 06 → (07 Archive)`

Each step runs an interactive Oz session in the current terminal: `goose run --recipe` streams
the agent's output to your shell and returns control when the agent ends its turn. The
script then verifies any required slot artifact and exits. Each step targets a **slot** —
a named directory under `~/.goose/state/plan_workflow/<slot>/` holding the plan state.

This workflow requires four named agent profiles: **Planner**, **Reviewer**, **Approver**,
and **Coder**. For recommended permission and autonomy settings for each profile, see
`docs/agent-profile-security.md`. That file also contains the Profile → Model mapping
table for the recommended open-model assignments.

## Step 00 — List Active Plans

**Purpose:** Survey active plans before creating a new one or resuming an existing one.

**Command:**
```bash
awk '/^## Active Plans/,/^## Archived/' ~/goose-agent-plans.md
```

**Expected output:** The Active Plans markdown table from `~/goose-agent-plans.md`.

**Placeholders:** None.

## Step 01 — Create + Pin New Plan

**Purpose:** Launch the Planner agent to create a new Warp plan and auto-pin the slot.

**Prerequisites:** `bin/goose-tools install globals` has been run. Current directory is inside a git repo.

**Command:**
```bash
~/.goose/workflows/scripts/goose_pw_plan.sh {{slot}} "{{plan-title}}" "{{plan-spec}}"
```

**Placeholders:**
- `{{slot}}` — lowercase alnum+hyphens, 1–32 chars (e.g. `myproject-cleanup`)
- `{{plan-title}}` — exact plan title as it will appear in the registry
- `{{plan-spec}}` — full plan specification in Markdown

**What the script does before launching:**
1. Validates slot name format
2. Checks for slot conflicts (fails if slot is already pinned to a different repo/plan)
3. Sources `~/.goose/state/plan_workflow/recipes.env`
4. Writes `repo_root` and `plan_title` directly to the slot directory
5. Builds the Planner prompt with the fully-resolved slot path

**What the Planner agent does:**
1. Calls `create_plan(title, markdown_content)` — captures `plan_id`
2. Appends a row to `~/goose-agent-plans.md` Active Plans table
3. Writes the `plan_id` to `~/.goose/state/plan_workflow/{{slot}}/plan_id`
4. Reports both operations completed with the plan_id

**Expected output:** Planner agent runs interactively in the current terminal, reports plan created, registry row written, and slot pinned. On completion, the script verifies `plan_id` exists and exits.

**Success indicator:** `~/.goose/state/plan_workflow/{{slot}}/plan_id` exists and contains a UUID.

**If this fails:** See `docs/troubleshooting.md` → "Orphaned registry row" or "Slot conflict on pin".

## Step 01b — Pin Existing Plan to Slot

**Purpose:** Pin an already-created active plan to a slot without launching an agent.

**Prerequisites:** The plan_id appears in the Active Plans table of `~/goose-agent-plans.md`.

**Command:**
```bash
~/.goose/workflows/scripts/goose_pw_select.sh {{slot}} {{plan-id}}
```

**Placeholders:**
- `{{slot}}` — the slot name to pin to
- `{{plan-id}}` — the UUID from the Active Plans table

**Validation order:** (1) UUID format, (2) present in Active Plans, (3) not in Archived,
(4) not in "plan not found", (5) no slot conflict.

**Expected output:** `Slot "{{slot}}" pinned:` with plan_id, plan_title, repo_root, then a
pointer to Step 02.

**If this fails:** See `docs/troubleshooting.md` → "Slot conflict on pin" or "Plan not found".

## Step 02 — First Review

**Purpose:** Launch Reviewer agent to produce a structured Section 0–6 review report.

**Prerequisites:** Slot is pinned (Step 01 or 01b complete). Run from the pinned repo's directory.

**Command:**
```bash
~/.goose/workflows/scripts/goose_pw_review.sh {{slot}} reviewer
```

**What the Reviewer does:**
1. `read_plans` → loads current plan
2. Multi-dimension analysis across Correctness, Completeness, Clarity, Consistency
3. Section 0–6 report with `[Rx]` recommendations and `[Dx]` decisions (cross-referenced)
4. Writes full report verbatim to `~/.goose/state/plan_workflow/{{slot}}/review_report.md`

**Agent conversation name:** `P02 Review — <plan_title>` (searchable in Conversation Panel)

**Expected output:** Reviewer agent runs interactively in the current terminal and produces a full Section 0–6 report ending with a persistence confirmation. On completion, the script warns if `review_report.md` was not written.

**Success indicator:** `~/.goose/state/plan_workflow/{{slot}}/review_report.md` exists and is non-empty.

**If this fails:** See `docs/troubleshooting.md` → "Missing agent profile after machine change".

## Step 03 — Edit

**Purpose:** Apply Reviewer-raised edits to the plan in a single `edit_plans` call.

**Prerequisites:** `review_report.md` exists in slot (from Step 02). Optionally populate `decisions.txt`.

**User actions before running Step 03:**

1. Read `~/.goose/state/plan_workflow/{{slot}}/review_report.md` (or reopen the Step 02
   Reviewer conversation from Warp's Conversation Panel — search `P02 Review — <plan-title>`).
2. Answer `[Dx]` questions into `~/.goose/state/plan_workflow/{{slot}}/decisions.txt`:
   - **Manual:** Write `D1: <answer>`, `D2: <answer>`, ... (blank lines and `#` lines ignored)
   - **Assisted:** Ask an agent to extract the `[Dx]` lines and write them to the file

**Command:**
```bash
~/.goose/workflows/scripts/goose_pw_edit.sh {{slot}}
```

**What the Reviewer does:** Loads `review_report.md` and `decisions.txt` via `read_files`,
loads the plan via `read_plans`, applies all accepted `[Rx]` recommendations in ONE `edit_plans` call.

**Expected output:** Reviewer agent runs interactively in the current terminal, applies plan edits, and reports which `[Rx]` items were applied and which `[Dx]` decisions were honored.

**If this fails:** `review_report.md missing or empty` → see `docs/troubleshooting.md` → "Stale review handoff".

## Step 04 — Second Review

**Purpose:** Launch Approver agent for a second-pass review. Overwrites `review_report.md`.

**Prerequisites:** Step 03 (Edit) complete. Run from the pinned repo's directory.

**Command:**
```bash
~/.goose/workflows/scripts/goose_pw_review.sh {{slot}} approver
```

**Agent conversation name:** `P04 Review — <plan_title>`

**Expected output:** Approver agent runs interactively in the current terminal and produces a second Section 0–6 report. Section 0 should say "ship" if the plan is ready.

**Success indicator:** `review_report.md` now contains the Approver's report (overwritten from Step 02's).

## Step 05 — Finalize

**Purpose:** Apply Approver-raised edits. Distinct script (Approver profile) per Decision D3.

**Prerequisites:** `review_report.md` exists and contains the Approver's Step 04 report.

**User action:** Update `decisions.txt` only if the Approver raised new `[Dx]` questions.

**Command:**
```bash
~/.goose/workflows/scripts/goose_pw_finalize.sh {{slot}}
```

**Expected output:** Approver agent runs interactively in the current terminal, applies final edits and confirms the plan is implementation-ready.

## Step 06 — Execute

**Purpose:** Launch Coder agent to implement the finalized, approved plan.

**Prerequisites:** Steps 01–05 complete. Current directory must match the slot's pinned `repo_root`.

**Command:**
```bash
~/.goose/workflows/scripts/goose_pw_execute.sh {{slot}} [fast]
```

**Optional `fast` flavor:** Pass `fast` as the second argument to use the `Coder (Fast)` profile
(`${CODER_FAST_ID}`). The `Coder (Fast)` profile and `CODER_FAST_ID` must already exist in
`recipes.env` (create the profile in Warp Settings → Agents → Profiles, then re-run
`bin/goose-tools install globals`). If `fast` is requested but `CODER_FAST_ID` is not set,
the script exits with an error.

**Expected output:** Coder agent runs interactively in the current terminal, reads the plan, implements it, runs any checks, and reports what was done.

**If this fails:** `repo_root mismatch` → see `docs/troubleshooting.md` → "repo_root moved or deleted".

## Step 07 — Archive (optional)

**Purpose:** Close out a completed plan by archiving the slot state and registry row.

**Commands:**
```bash
# Archive slot state (preferred — preserves files with original mtime)
bin/goose-tools slot archive {{slot}}

# Or clear the slot entirely
bin/goose-tools slot clear {{slot}}
```

Then move the registry row from Active to Archived in `~/goose-agent-plans.md` (use the
`manage-plans` skill or edit manually).

---

## Notebook Sync

The `Plan → Execute Workflow` goose-tools operator guide (`wXnnmpNmcsmOKwSwnMgUNv`) is sourced
from `warp/notebooks/plan-execute-workflow.md`. After editing the notebook source, you
must manually re-import it in Goose Desktop for the changes to take effect. See
`docs/troubleshooting.md` → "Goose Desktop Notebook Drift from Canonical Source".

---

## End-to-End Sample Run

Slot: `example-demo` | Plan title: `Add retry logic to pipeline`

```bash
# Step 00: check active plans
awk '/^## Active Plans/,/^## Archived/' ~/goose-agent-plans.md

# Step 01: create and pin
~/.goose/workflows/scripts/goose_pw_plan.sh \
  example-demo \
  "Add retry logic to pipeline" \
  "## Problem\nThe DLT import pipeline fails on transient network errors without retrying.\n## Solution\nAdd exponential backoff retry logic with configurable max attempts."

# [Planner agent runs, plan created, slot pinned]
# => plan_id: e.g. a1b2c3d4-e5f6-7890-abcd-ef1234567890

# Step 02: first review
~/.goose/workflows/scripts/goose_pw_review.sh example-demo reviewer
# [Reviewer produces Section 0-6 report, writes review_report.md]

# Step 03: answer decisions, edit
echo "D1: Use 3 retries with 2x backoff starting at 1s" \
  > ~/.goose/state/plan_workflow/example-demo/decisions.txt
~/.goose/workflows/scripts/goose_pw_edit.sh example-demo
# [Reviewer applies edits]

# Step 04: second review
~/.goose/workflows/scripts/goose_pw_review.sh example-demo approver
# [Approver overwrites review_report.md, recommends ship]

# Step 05: finalize
~/.goose/workflows/scripts/goose_pw_finalize.sh example-demo
# [Approver confirms implementation-ready]

# Step 06: execute
~/.goose/workflows/scripts/goose_pw_execute.sh example-demo
# [Coder implements the plan]

# Step 07: archive
bin/goose-tools slot archive example-demo
# Then move registry row to Archived in ~/goose-agent-plans.md
```

Last Updated: 2026.05.02 @ 23:29:08
