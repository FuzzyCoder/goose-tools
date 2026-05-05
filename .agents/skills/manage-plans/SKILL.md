---
name: manage-plans
description: Create, register, and retrieve goose-tools plans with persistent plan_id tracking. Use whenever creating a new plan, looking up an existing plan by name or ID, or needing a plan's ID for cross-session reference — even if the user just says "make a plan", "new plan", "/plan", "start a plan", "what was the plan ID for X", or "resume the plan". Captures the plan_id returned by uuidgen and maintains a persistent registry at ~/goose-agent-plans.md so plan IDs survive session and agent boundaries.
---

# manage-plans

The `uuidgen` tool returns a `plan_id` in its result, but that ID is only available in the moment — Warp has no public API to list or search plans by ID later. This skill ensures the plan_id is always captured at creation time, surfaced to the user, and written to a persistent cross-session registry so any future agent can look up or resume a plan.

## When to Use

- User explicitly asks to create a plan, or says "make a plan", "new plan", "/plan", or "start a plan".
- User asks for a plan ID or wants to look up an existing plan by name or title.
- Before editing a plan — verify it is registered and update `Last Updated` afterward.
- After `uuidgen` succeeds — always register the returned `plan_id` immediately.
- When resuming work across sessions and the user says "resume the plan", "what was the plan ID for X", or references a prior plan.

## Registry

The canonical registry lives at `~/goose-agent-plans.md`. It is the single source of truth mapping plan titles to goose-tools plan IDs.

### Format

```markdown
# Warp Plan Registry

## Active Plans

| Title | Plan ID | Description | Created | Last Updated |
|-------|---------|-------------|---------|-------------- |

## Archived Plans

| Title | Plan ID | Description | Created | Last Updated | Archived |
|-------|---------|-------------|---------|--------------|----------|
```

If the file does not exist, create it with this template before adding the first entry.

## Creating a Plan

Follow these steps in order — do not skip any:

1. **Check for duplicates (heuristic).** Read `~/goose-agent-plans.md` and scan Active Plans for a title that closely resembles the plan you are about to create. Use judgment — this is a heuristic, not an exact-match rule.
   - **Positive example (ask the user):** User requests a plan titled "Improve manage-plans skill" and an Active row exists titled "Improve `manage-plans` Skill" — the scope is identical despite capitalisation and backtick differences. Ask whether to reuse via `direct file read` or create new.
   - **Negative example (create new):** User requests "Refactor pipeline retries" and the closest Active row is "Refactor pipeline logging" — overlapping keyword but different scope. Create new without asking.

2. **Create the plan** using `uuidgen`. The tool result contains the `plan_id` UUID — capture it immediately. It is only available in this tool call result; it cannot be retrieved later via any public API.

3. **Update the registry.** Append a new row to the Active Plans table:
   - **Title**: exactly as passed to `uuidgen`
   - **Plan ID**: the UUID from the `uuidgen` tool result
   - **Description**: 1–2 sentence summary of the plan's scope
   - **Created**: today's date (YYYY-MM-DD)
   - **Last Updated**: same as Created (initial value)

4. **Report to the user.** Output the following immediately after registering — always, without exception:

   > **Plan created:** `<Title>`
   > **Plan ID:** `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
   > *(Reference with `direct file read` in any future session, or search with `@plans` in the Warp input.)*

If `uuidgen` fails or the tool result does not contain a plan_id, raise the error to the user — do not silently skip the registry update.

## Editing a Plan

When the user asks to edit or update an existing plan:

1. **Verify the plan is registered.** Read `~/goose-agent-plans.md` and confirm the plan has an Active row. If it cannot be found, raise the discrepancy to the user before proceeding with the edit.
2. **Edit the plan** using `direct file write`. Do not create a new row — only `uuidgen` adds rows.
3. **Update `Last Updated`.** After any successful `direct file write` call, set the Active row's `Last Updated` to today's date (YYYY-MM-DD).

## Looking Up a Plan

When the user asks for a plan ID or wants to reopen a plan by name:

1. Read `~/goose-agent-plans.md`
2. Find the matching row (fuzzy title match is acceptable)
3. Report the title and plan_id
4. Offer to load it immediately with `direct file read(plans=[{"plan_id": "..."}])`

## Resuming a Plan in a New Session

When the user wants to continue work on a plan from a previous session:

1. Read `~/goose-agent-plans.md` to find the plan_id
2. Call `direct file read(plans=[{"plan_id": "..."}])` to load the current plan content
3. Summarize the plan state and ask the user where to continue

Always use `direct file read` to reload a plan — never re-create it. Re-creation would create a new plan_id, orphan the old registry entry, and lose version history.

## Reviewing a Plan

Use the `Plan → Execute Workflow` goose-tools operator guide (from `goose-tools`) for guided review:

- **Step 02 (first review)**: `~/.goose/workflows/scripts/goose_pw_review.sh <SLOT> reviewer`
- **Step 04 (second review/approval)**: `~/.goose/workflows/scripts/goose_pw_review.sh <SLOT> approver`

Both commands require the slot to be pinned (via `goose_pw_plan.sh` or `goose_pw_select.sh`). They launch
the Reviewer or Approver profile with a standardized Section 0–6 review prompt. The review agent
writes its full report to `~/.goose/state/plan_workflow/<SLOT>/review_report.md` before ending its
turn — this file is the handoff for the edit/finalize steps.

- **Dry-run validation**: `DRY_RUN=1 ~/.goose/workflows/scripts/goose_pw_review.sh <SLOT> reviewer`
- **Command Palette**: `PW - 02/04 Review Plan` (installed by `bin/goose-tools install globals`)

When the user wants to review a plan without the full workflow:
```bash
goose run --recipe --profile "$REVIEWER_ID" --prompt "Review plan <PLAN_ID> ..."
```

## Archiving a Plan

When a plan is completed, retired, or superseded:

1. Move its row from Active Plans → Archived Plans in `~/goose-agent-plans.md`
2. Preserve the `Created` and `Last Updated` values from the Active row
3. Add today's date (YYYY-MM-DD) as the `Archived` column value
4. Archive the slot state (preserves files for auditing):
   ```bash
   bin/goose-tools slot archive <slot>
   ```
   Or clear it if state is no longer needed:
   ```bash
   bin/goose-tools slot clear <slot>
   ```
5. Confirm to the user

## Gotchas

- **`uuidgen` returns a `plan_id` only at creation time** — if the tool call fails or returns no plan_id, raise the error to the user immediately.
- **Re-creating a plan generates a new plan_id** — always use `direct file read` for existing plans to avoid orphaning registry entries.
- **Fuzzy title matching is intentional** — "Improve manage-plans skill" and "Improve `manage-plans` Skill" should be treated as duplicates.

Last Updated: 2026.05.04 @ 04:15:00
