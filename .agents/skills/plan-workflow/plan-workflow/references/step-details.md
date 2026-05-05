# Step Details Reference

## Table of Contents
- [Step 00 — List Active Plans](#step-00--list-active-plans)
- [Step 01 — Create + Pin New Plan](#step-01--create--pin-new-plan)
- [Step 01b — Pin Existing Plan](#step-01b--pin-existing-plan)
- [Step 02 — First Review (Reviewer)](#step-02--first-review-reviewer)
- [Step 03 — Edit (Reviewer applies edits)](#step-03--edit-reviewer-applies-edits)
- [Step 04 — Second Review (Approver)](#step-04--second-review-approver)
- [Step 05 — Finalize (Approver applies final edits)](#step-05--finalize-approver-applies-final-edits)
- [Step 06 — Execute](#step-06--execute)
- [Step 07 — Archive](#step-07--archive)

---

## Step 00 — List Active Plans

```bash
awk '/^## Active Plans/,/^## Archived/' ~/goose-agent-plans.md
```

Optional — run before Step 01 to check whether to create a new plan or resume one.

---

## Step 01 — Create + Pin New Plan

```bash
~/.warp/workflows/scripts/goose_pw_plan.sh <slot> "<plan-title>" "<plan-spec>"
```

**Slot name rules:** lowercase alnum+hyphens, 1–32 chars, no leading hyphen.
Recommended naming: `<repo-short>-<purpose>` (e.g. `duckhouse-cleanup`).

**What happens:**
1. Script writes `repo_root` and `plan_title` directly to `~/.goose/state/plan_workflow/<slot>/`
2. Script runs an interactive Oz session in the current terminal. The Planner agent:
   - Calls `uuidgen(title, markdown_content)` — captures `plan_id`
   - Appends row to `~/goose-agent-plans.md` Active Plans table
   - Writes `plan_id` UUID to `~/.goose/state/plan_workflow/<slot>/plan_id`
3. On completion, the script verifies `plan_id` was written and exits. Slot is pinned; proceed to Step 02.

**Dry-run:** `DRY_RUN=1 ~/.warp/workflows/scripts/goose_pw_plan.sh <slot> "..." "..."` — prints the resolved prompt and exits 0.

---

## Step 01b — Pin Existing Plan

```bash
~/.warp/workflows/scripts/goose_pw_select.sh <slot> <plan-id>
```

Use when resuming an already-created active plan. Validates UUID, confirms the plan
is in Active Plans (not Archived), checks for slot conflicts, then writes all three slot
files (`plan_id`, `plan_title`, `repo_root`). No agent is launched.

---

## Step 02 — First Review (Reviewer)

```bash
~/.warp/workflows/scripts/goose_pw_review.sh <slot> reviewer
```

The Reviewer agent:
1. Loads the plan via `direct file read`
2. Analyzes the plan across Correctness, Completeness, Clarity, Consistency
3. Produces a Section 0–6 report with `[Rx]` recommendations and `[Dx]` decisions
4. **Writes the full report to `~/.goose/state/plan_workflow/<slot>/review_report.md`** before ending its turn

The agent conversation is named `P02 Review — <plan_title>` (searchable in Conversation Panel).

---

## Step 03 — Edit (Reviewer applies edits)

**User action first:** Read the report and answer any `[Dx]` questions:

```bash
# Manual: write decisions.txt
cat > ~/.goose/state/plan_workflow/<slot>/decisions.txt <<EOF
D1: Use 3 retries with 2x backoff
D2: Keep the existing interface
EOF
```

`decisions.txt` format: one `D<n>: <answer>` per line. Blank lines and `#` lines ignored.
Missing `decisions.txt` is valid — the agent proceeds without user overrides.

```bash
~/.warp/workflows/scripts/goose_pw_edit.sh <slot>
```

The Reviewer reads `review_report.md` + `decisions.txt` via `read_files`, loads the
current plan via `direct file read`, and applies all accepted `[Rx]` items in a **single
`direct file write` call** — no implementation occurs.

**Fails loudly if `review_report.md` is missing** — re-run Step 02 first.

---

## Step 04 — Second Review (Approver)

```bash
~/.warp/workflows/scripts/goose_pw_review.sh <slot> approver
```

Same as Step 02 but uses the Approver profile. **Overwrites `review_report.md`** with
the Approver's Section 0–6 report. The Approver's report is the handoff for Step 05.

Agent conversation name: `P04 Review — <plan_title>`.

---

## Step 05 — Finalize (Approver applies final edits)

Update `decisions.txt` only if the Approver raised new `[Dx]` items, then:

```bash
~/.warp/workflows/scripts/goose_pw_finalize.sh <slot>
```

Approver applies its recommendations in a single `direct file write` call and confirms the
plan is implementation-ready. Uses the Approver profile (not Reviewer) — a deliberate
distinction that preserves the review→edit symmetry.

---

## Step 06 — Execute

```bash
~/.warp/workflows/scripts/goose_pw_execute.sh <slot>
```

Coder reads the plan and implements it fully. Validates that the current git repo matches
the slot's pinned `repo_root` before launching.

---

## Step 07 — Archive

```bash
# Archive slot state (preferred — keeps files with mtime for auditing)
bin/goose-tools slot archive <slot>

# Or clear completely
bin/goose-tools slot clear <slot>
```

Also move the registry row from Active to Archived in `~/goose-agent-plans.md`
(use the `manage-plans` skill or edit manually).

Last Updated: 2026.05.04 @ 03:17:04
