---
name: review-plan
description: Review a plan for Correctness, Completeness, Clarity, and Consistency via multi-dimension analysis. Produces structured findings with issues, implications, and recommendations. Supports iterative review cycles until the plan is implementation-ready. Use this skill whenever the user asks to review, analyze, or critique a plan — even if they say "check the plan", "is this plan correct?", or "what's wrong with this plan?"
---

# Plan Review Workflow

Iterative review of implementation plans using multi-dimension analysis and codebase cross-referencing.
Each cycle analyzes the plan across four dimensions and produces a structured report with
actionable recommendations. Edits are applied only after the user approves them.

## When to Use

- User explicitly asks to review, analyze, or critique a plan
- User asks "what's wrong with this plan?" or "is this plan correct?"
- Before executing a plan that was written by someone else or in a prior session
- After significant changes to a plan's scope or approach

## Core principle

**DO NOT modify the plan or implement anything during review.** Analysis and edits are
separate turns. Never conflate "review" with "apply" — only apply recommendations when
the user explicitly says to.

---

## Profile role guidance

This skill is used by two profiles with distinct review modes:

**Reviewer mode (Steps 02/03 of the Plan → Execute Workflow):**
Fresh analytical critique. Interleave codebase lookups throughout analysis.
Apply first-principles correctness — challenge every technical claim independently.
The frame is: “is the plan logically sound?”

**Approver mode (Steps 04/05 of the Plan → Execute Workflow):**
Coder-executability gate. The frame shifts to:
“will a coding agent be able to execute each step of this plan without
re-inventing the spec or stalling on missing specifications or ambiguous
instructions?”
Treat every ambiguity that would force the Coder to make an undocumented
architectural decision as a blocker, regardless of whether it was flagged
in the first review.

When used outside the workflow (ad-hoc review), default to Reviewer mode framing.

---

## Step 1 — Research before analysis

Read the plan and cross-reference it against the actual codebase **before** forming any
judgments. Do not analyze from memory.

```
1. read_plans to load the target plan
2. grep / read_files for every file, function, and schema element the plan references
3. Verify claims in the "Current State" section against live code
4. Note any discrepancies between what the plan asserts and what exists
```

Only look up external documentation (context7, tavily, fetch) when the plan relies on
external framework behavior that cannot be verified from the local codebase.

---

## Step 2 — Multi-dimension analysis

Analyze the plan across Correctness, Completeness, Clarity, and Consistency, then synthesize blockers vs polish issues. The agent decides its own analysis process; do not enumerate step counts, named "thoughts", or sub-steps.

---

## Step 3 — Structured report

Report findings in this exact format. Do not deviate from the section numbering.

```
0 Overall Findings
1 Correctness
    1a Issues & Implications
    1b Recommendations
2 Completeness
    2a Issues & Implications
    2b Recommendations
3 Clarity
    3a Issues & Implications
    3b Recommendations
4 Consistency
    4a Issues & Implications
    4b Recommendations
5 All Recommendations (each citing the relevant Issue, e.g. [R3] → Issue 1a)
6 All Required Decisions (each referencing relevant Issue and Recommendation)
```

### Report conventions

- **Good** findings belong in section 0 and the relevant section — call out what the plan
  gets right, not just what's wrong
- **Issues** state the problem factually, tied to a specific plan line or section
- **Implications** explain what could go wrong if the issue is not fixed
- **Recommendations** are always numbered `[R1]`, `[R2]`, etc. and restated verbatim in
  section 5 with the same numbers
- Recommendations that depend on a user decision should cross-reference the relevant
  `[Dx]` item rather than embedding the question inline
- **Decisions** are questions that REQUIRE the user to choose before implementation can
  proceed. Label them `[D1]`, `[D2]`, etc. Each must cite the relevant Issue and, when
  one exists, the relevant Recommendation (e.g., `[D1] → Issue 1a, [R3]` or
  `[D1] → Issue 2a` when no `[Rx]` applies). Decisions are NOT agent-applicable — they
  are user-gate items.
- Distinct from Recommendations: a Recommendation is an edit an agent can apply; a
  Decision requires a user answer first
- **Cross-references** — both `[Rx]` items in Section 5 and `[Dx]` items in Section 6
  must cite the relevant Issue (e.g., `[R3] → Issue 1a`, `[D1] → Issue 2a, [R5]`)
- Keep recommendations actionable: specific enough for an implementer to act without
  re-reading the full analysis

---

## Step 3b — Persist the report (when running in a slot context)

If the review was launched via `goose_pw_review.sh` (i.e., the prompt contains a
`REVIEW REPORT PERSISTENCE CONTRACT` block with a file path), you MUST write the
full Section 0–6 report verbatim to the specified path before ending your turn.

This is the handoff mechanism used by `goose_pw_edit.sh` / `goose_pw_finalize.sh` — the
next step's agent reads the file rather than reconstructing the review from context.

```bash
# The path is injected by goose_pw_review.sh, e.g.:
# ~/.goose/state/plan_workflow/<slot>/review_report.md
```

Use `create_file` or `run_shell_command` to write it. Overwrite any prior contents.
If no persistence contract is present, skip this step.

---

## Step 4 — Apply recommendations (only when user asks)

When the user says "apply all recommendations" (or similar):

1. Re-read the plan from `read_plans` to get exact current content
2. Apply **all accepted recommendations in a single `edit_plans` call**
   — never make multiple sequential edits
3. For any recommendation that requires a user decision, assign it a `[Dx]` label in
   Section 6 and encode the decision in the plan as
   `[Dx] Decision needed before implementation: <question>`
4. Update the plan's timestamp if it has one

---

## Step 5 — Iterate if needed

After applying recommendations, the user may ask for another review pass. The second
pass should focus only on whether:
- Previous issues are now fully resolved
- The applied recommendations introduced new ambiguities
- Any new issues emerged from the edits themselves

A plan is implementation-ready when the remaining issues are all **polish** (clarity
tweaks, minor completeness) rather than **blockers** (incorrect technical claims, missing
specifications that would produce divergent implementations).

---

## Dimension definitions

### Correctness
Technical claims match the actual codebase. Join paths match the schema. Proposed
method signatures are compatible with existing callers. Proposed constants have correct
types and values. "Already implemented" items are actually implemented.

### Completeness
All specifications needed to implement unambiguously are present. Follow-on updates
(documentation, CLI help text, docstrings, related modules) are in scope. Tests cover
all new behavior paths. Decision points are flagged, not silently defaulted.

### Clarity
No phrase that could produce two materially different implementations. Source precedence
is stated. Deduplication rules are defined. JOIN semantics are explicit (INNER vs LEFT).
Field parsing rules are specified (e.g., "split on `' | '`" not "parse the field").

### Consistency
New additions match the naming conventions and idioms of the existing codebase. Toggle/
CLI/docstring descriptions stay accurate after the change. Parallelization assignments
don't create merge conflicts on shared files. Type and enum mappings stay aligned.

---

## Common pitfall patterns

| Pattern | What to check |
|---|---|
| Join by assumed key | Verify the actual join columns exist in the schema; may require composite keys |
| Pipe-delimited fields | Confirm delimiter and specify the split rule explicitly in the plan |
| Shared toggle or flag | Confirm all user-facing descriptions and help text are updated together |
| Static method with new behavior | Check if instance state is now needed; may require conversion to instance method |
| Parallel agents editing same file | Assign file ownership explicitly to avoid merge conflicts |
| "Not implemented yet" list | Verify each item is truly absent in current code before scheduling |
| New enum or type value | Verify it's registered in all maps, validators, and coverage logic |
| New config key | Confirm default value, type, and all consumers are updated together |

---

## Example invocation

```
User: Review plan abc123 for correctness, completeness, clarity, and consistency.
      DO NOT modify the plan. DO NOT implement.

→ Step 1: read_plans + grep/read_files to cross-reference all claims.
  Step 2: Analyze the plan.
  Step 3: Report in sections 0–6. Sections 5 and 6 must include cross-references:
    [R3] → Issue 1a          (recommendation cites its source issue)
    [D1] → Issue 2a, [R5]   (decision cites its issue and related recommendation)
  Wait for user direction before Step 4.
```

```
User: Apply all recommendations.

→ Run Step 4 (single edit_plans call). [Dx] items are encoded in the plan as
  Decision notes — not applied by the agent. Confirm no implementation.
```

```
User: Run another review pass.

→ Run Steps 1–3 again, focusing on whether previous issues are resolved.
```

## Integration with Plan → Execute Workflow

The `plan-workflow` skill orchestrates the full Plan→Review→Edit→Approve→Finalize→Execute
cycle using `goose_pw_review.sh`. When launched through that workflow:
- The prompt already specifies the plan ID, repo CWD, and persistence file path
- Use the prompt as the authoritative source for those values
- Complete Steps 1–3b as specified above before ending your turn
- Wait for user direction before any Step 4 actions

## Gotchas

- **Never modify plans during review** — analysis and edits are separate turns.
- **Do not enumerate step counts or named "thoughts"** — the agent decides its own analysis process.
- **"DO NOT implement" requests must be honored** — even "continue" after analysis means continue analysis, not implementation.

Last Updated: 2026.05.04 @ 04:15:00
