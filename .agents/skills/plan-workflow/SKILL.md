---
name: plan-workflow
description: Drive the Plan→Execute workflow using goose_pw_*.sh scripts and slot state. Use whenever the user says "create a plan slot", "start the plan workflow", "pin a plan", "run the review step", "apply edits", "execute the plan", "archive the slot", or asks how to use the Plan→Execute Workflow notebook. Also use when the user asks about slot state, decisions.txt, review_report.md, or profile IDs. NOT for creating plans without the slot workflow (use manage-plans for that).
---

# Plan → Execute Workflow

Structured multi-agent workflow for planning, reviewing, and implementing work.
Each plan lives in an isolated **slot** at `~/.goose/state/plan_workflow/<slot>/` so
multiple plans can run concurrently in separate terminals without interference.

## When to Use

- User asks to "start the plan workflow", "create a slot", or "pin a plan"
- User wants to review, edit, finalize, or execute a plan via the agent workflow
- User asks about slot state, `review_report.md`, `decisions.txt`, or profile IDs
- User is using the `Plan → Execute Workflow` goose-tools operator guide
- NOT for ad-hoc plan creation without slot management (use `manage-plans` for that)

## Prerequisites

- `bin/goose-tools install globals` has been run (writes `recipes.env`, installs scripts)
- Agent profiles named **Planner**, **Reviewer**, **Approver**, **Coder** exist in Warp
- All workflow commands must run from inside a git repository

## The 9-Step Loop (Overview)

```
(00 List) → 01 Create+Pin | 01b Pin Existing → 02 Review → 03 Edit →
             04 Approve  → 05 Finalize       → 06 Execute → (07 Archive)
```

Each step runs an interactive Oz session in the current terminal: `goose run --recipe` streams
the agent's output to your shell and returns control when the agent ends its turn.
See `references/step-details.md` for full step-by-step descriptions.

---

## Slot State Files

Each slot directory (`~/.goose/state/plan_workflow/<slot>/`) contains:

| File | Written by | Required for |
|------|-----------|-------------|
| `repo_root` | `goose_pw_plan.sh` script (directly) | Steps 02–06 |
| `plan_title` | `goose_pw_plan.sh` script (directly) | Step 02 name |
| `plan_id` | Planner agent | Steps 02–06 |
| `review_report.md` | Reviewer/Approver agent | Steps 03, 05 |
| `decisions.txt` | User | Steps 03, 05 (optional) |

**Key invariant:** `repo_root` and `plan_title` are ALWAYS written by the script directly,
never delegated to an agent. `plan_id` is ALWAYS written by the Planner agent — the
script never scrapes `~/goose-agent-plans.md` to infer it.

---

## Profile IDs

Profile IDs are resolved at install time and stored in `~/.goose/state/plan_workflow/recipes.env`:

```bash
cat ~/.goose/state/plan_workflow/recipes.env
# PLANNER_ID=beGG8UupUHnl1elljuhBlC
# REVIEWER_ID=Aq4GINdXRjWsYofK5UPbWz
# APPROVER_ID=afFAzamLvFyGlqNkpxL7Qq
# CODER_ID=aJf1ufOU8qlCwH0b80Y1MI
# CODER_FAST_ID=<set after creating the optional Coder (Fast) profile>
```

**Model assignments** — configure each profile's model in Warp Settings → Agents → Profiles:

| Profile | Model | Status |
|---|---|---|
| Planner | Qwen 3.6 Plus | Verify availability in Warp UI before assigning |
| Reviewer | GLM 5 (`glm-5-fireworks`) | Warp-documented |
| Approver | Kimi K2.5 (`kimi-k25-fireworks`) | Warp-documented |
| Coder | Kimi K2.6 | Verify availability in Warp UI before assigning |
| Coder (Fast) | MiniMax 2.7 | Optional profile; verify availability in Warp UI |

All models are from the open-model pool. No Auto routing. No proprietary closed models.
See `docs/agent-profile-security.md` for the full profile configuration reference.

If `recipes.env` is missing: run `bin/goose-tools install globals`.
If profile IDs change (new machine, account change): re-run `bin/goose-tools install globals`.

---

## Parallelism

Multiple slots run concurrently without interference — each has isolated state at
`~/.goose/state/plan_workflow/<slot>/`. Steps 01→02 are sequential (slot must be pinned
before review). After pinning, separate slots can progress independently.

## Gotchas

- **Steps 01→02 are sequential** — a slot must be pinned before review can start.
- **`recipes.env` is resolved at install time** — if missing, run `bin/goose-tools install globals`.
- **Model assignments must be verified in Warp UI** — availability changes; don't assume model IDs are stable.

## References Structure

- `references/step-details.md` — Full descriptions of Steps 00–07
- `references/troubleshooting.md` — DRY_RUN pattern, health check, and troubleshooting quick reference

Last Updated: 2026.05.04 @ 04:15:00
