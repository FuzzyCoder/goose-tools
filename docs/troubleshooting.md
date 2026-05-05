# Troubleshooting

Common failure modes and recovery steps for the `warp-tools` Plan→Execute workflow.

---

## Orphaned Registry Row

**Symptom:** `~/warp-agent-plans.md` has a new Active row but `~/.warp/state/plan_workflow/<slot>/plan_id` is missing.

**Cause (Scenario A):** `oz_pw_plan.sh` wrote `repo_root` and `plan_title` to the slot, the Planner created the plan and wrote the registry row, but failed before writing `plan_id` (e.g. interrupted by Ctrl-C).

**Detection:** `bin/warp-tools doctor` reports `Scenario A — plan_id missing`.

**Recovery:**
```bash
# Option 1: Clear the slot and re-run Step 01 with the same PLAN_SPEC
bin/warp-tools slot clear <slot>
~/.warp/workflows/scripts/oz_pw_plan.sh <slot> "<title>" "<spec>"

# Option 2: If the plan WAS created in Warp (check ~/warp-agent-plans.md for a UUID),
# manually write the plan_id and use Step 01b instead:
printf '<UUID>' > ~/.warp/state/plan_workflow/<slot>/plan_id
~/.warp/workflows/scripts/oz_pw_select.sh <slot> <UUID>
```

---

## Stale Review Handoff

**Symptom:** `oz_pw_edit.sh` or `oz_pw_finalize.sh` fails with `review_report.md missing or empty`.

**Cause:** The review agent (Step 02 or 04) did not write `review_report.md` before ending its turn.
This can happen if the agent was interrupted, or if the Review Report Persistence Contract was not
followed.

**Detection:** `bin/warp-tools doctor` reports `stale handoff — decisions.txt present but review_report.md missing`.

**Recovery:**
```bash
# Re-run the review step (Step 02 or 04) which will overwrite review_report.md
~/.warp/workflows/scripts/oz_pw_review.sh <slot> reviewer   # for Step 02
~/.warp/workflows/scripts/oz_pw_review.sh <slot> approver  # for Step 04
```

---

## Slot Conflict on Pin

**Symptom:** `oz_pw_plan.sh` or `oz_pw_select.sh` fails with `slot conflict`.

**Cause:** The slot already exists and is pinned to a different repo or plan.

**Recovery:**
```bash
# View what's in the slot
ls -la ~/.warp/state/plan_workflow/<slot>/
cat ~/.warp/state/plan_workflow/<slot>/repo_root
cat ~/.warp/state/plan_workflow/<slot>/plan_id

# If the slot state is stale or wrong, clear it (interactive confirmation)
bin/warp-tools slot clear <slot>

# Then re-run the desired step
```

---

## Plan Not Found in Registry

**Symptom:** `oz_pw_select.sh` fails with `plan not found in registry`.

**Cause:** The UUID is not present in either Active or Archived tables of `~/warp-agent-plans.md`.

**Recovery:**
```bash
# List all plans (active and archived) to find the correct UUID
cat ~/warp-agent-plans.md

# If the plan exists in Warp but not in the registry (registry drift),
# look up the plan_id from the Warp plan tool (read_plans in an agent session)
# then manually append the row to ~/warp-agent-plans.md per the manage-plans skill.
```

---

## Plan is Archived, Not Resumable

**Symptom:** `oz_pw_select.sh` fails with `plan is archived, not resumable`.

**Cause:** The UUID refers to a plan in the Archived Plans table.

**Recovery:** Create a new plan (Step 01) with updated content. Do not attempt to resume archived plans.

---

## repo_root Moved or Deleted

**Symptom:** `oz_pw_review.sh`, `oz_pw_edit.sh`, `oz_pw_finalize.sh`, or `oz_pw_execute.sh` fails with
`current repo does not match slot pinned repo`.

**Detection:** `bin/warp-tools doctor` reports `repo_root no longer exists on disk`.

**Cause:** The git repo was moved or the worktree was deleted since the slot was pinned.

**Recovery:**
```bash
# Clear the slot and re-pin from the new location
bin/warp-tools slot clear <slot>
cd /path/to/new/repo/location
~/.warp/workflows/scripts/oz_pw_select.sh <slot> <PLAN_ID>
```

---

## Missing Agent Profile After Machine Change

**Symptom:** `oz_pw_review.sh` fails with `REVIEWER_ID not set in profiles.env`, or `bin/warp-tools install globals` fails with `missing required agent profiles`.

**Cause:** Agent profiles are per-Warp-account. After moving to a new machine or signing in with a different account, the profile IDs change.

**Recovery:**
```bash
# Verify which profiles exist on this machine
oz agent profile list

# Create missing profiles in Warp (Settings → Agent Profiles) with exact display names:
# Planner, Reviewer, Approver, Coder

# Re-install to regenerate profiles.env
bin/warp-tools install globals
```

---

## Warp Drive Notebook Drift from Canonical Source

**Symptom:** The live `Plan → Execute Workflow` notebook in Warp Drive has different content
from `warp/notebooks/plan-execute-workflow.md`.

**Detection:** Manual inspection — compare the Warp Drive notebook to the canonical source file.

**Recovery:**
1. Edit `warp/notebooks/plan-execute-workflow.md` in the `warp-tools` repo with the desired changes.
2. Export the updated canonical source to Warp Drive: Warp Drive → Notebooks → Import → select the file.
3. Archive or delete the outdated notebook version in Warp Drive.

---

## Shell-Compatibility Failure

**Symptom:** A script behaves differently under `bash` vs `zsh` — different output, different exit code, or syntax errors.

**Detection:** `tests/shell_compat/run_compat.sh` reports failures under one interpreter.

**Recovery:**
1. Identify the failing script and interpreter from the compat test output.
2. Review the script for forbidden constructs (see `docs/shell-compatibility.md`).
3. Replace the forbidden construct with its POSIX+common-subset equivalent.
4. Re-run `bash tests/shell_compat/run_compat.sh` and `zsh tests/shell_compat/run_compat.sh` to confirm.
5. Run `bin/warp-tools install globals` to propagate the fix to global locations.

Last Updated: 2026.04.24 @ 21:54:03
