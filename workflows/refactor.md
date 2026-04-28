# Refactor Workflow

## Paths

All artifact paths in this workflow are relative to the run directory: `.sdlc/runs/{run-id}/`.
For example, `artifacts/refactor/plan.md` resolves to `.sdlc/runs/{run-id}/artifacts/refactor/plan.md`.
The knowledge base (`knowledge/`) is shared across runs and lives at `.sdlc/knowledge/`.

## Trigger

Code refactoring — improving structure, readability, or performance without changing behavior.

Signals: "refactor", "clean up", "restructure", "improve code quality", "reduce tech debt", "reorganize".

## Step Skipping

Any step can be skipped if its expected output artifacts already exist in the run directory before execution begins.

---

## Steps

### Step 1: Analyze Code

- **ID**: analysis
- **Agent**: implementer (analysis mode)
- **Inputs**: Source code, `knowledge/architecture.md`, `knowledge/conventions.md`, `knowledge/components/`, user's refactoring request
- **Outputs**: `artifacts/refactor/plan.md`
- **Checkpoint**: true
- **On failure**: escalate
- **Description**: Read the existing codebase and the user's request. Identify what needs to change, why, and how. Produce a detailed refactoring plan listing each change, its rationale, and affected files. Do NOT modify any code in this step.

---

### Step 2: Review Refactoring Plan

- **ID**: plan-review
- **Agent**: reviewer
- **Depends on**: analysis
- **Inputs**: `artifacts/refactor/plan.md`, source code, `knowledge/architecture.md`
- **Outputs**: `artifacts/review/feedback.md`
- **Checkpoint**: true
- **On failure**: escalate
- **On rejection**: Route `artifacts/review/feedback.md` to step `analysis`. Re-run step `analysis` with the reviewer's concerns.
- **Description**: Review the refactoring plan for safety. Verify the proposed changes won't break existing functionality. Check that the plan aligns with the project's architecture and conventions.

---

### Step 3: Execute Refactoring

- **ID**: refactoring
- **Agent**: implementer
- **Depends on**: plan-review
- **Inputs**: `artifacts/refactor/plan.md`, `artifacts/review/feedback.md`, source code
- **Outputs**: modified source code, `artifacts/implementation/progress.md`
- **Checkpoint**: false
- **On failure**: retry(3), then escalate
- **Description**: Apply the refactoring changes as described in the plan. Follow the plan exactly — do not introduce additional changes beyond what was planned and approved.

---

### Step 4: Verify No Regressions

- **ID**: verification
- **Agent**: tester (mode: execution)
- **Depends on**: refactoring
- **Inputs**: source code, existing test files
- **Outputs**: `artifacts/testing/test-results.md`
- **Checkpoint**: false
- **On failure**: Route `artifacts/testing/test-results.md` to step `refactoring`. Re-run step `refactoring` with test failures as input.
- **Description**: Run the existing test suite. All tests must pass — refactoring should not change behavior. If tests fail, the refactoring introduced a bug. If no tests exist, note this as a gap but do not block.

---

### Step 5: Update Documentation

- **ID**: documentation
- **Agent**: documenter
- **Depends on**: verification
- **Inputs**: all artifacts, source code, `knowledge/`
- **Outputs**: `artifacts/documentation/`, `knowledge/`
- **Checkpoint**: false
- **On failure**: retry(2), then escalate
- **Description**: Update the knowledge base to reflect structural changes. Update component docs, architecture doc, and conventions if the refactoring changed them. Append a changelog entry.

---

### Step 6: Retrospective

- **ID**: retrospective
- **Agent**: retrospective
- **Depends on**: documentation
- **Inputs**: `telemetry.json` (in the run directory), all artifacts, current framework files
- **Outputs**: `artifacts/evolution/proposal-{date}.md` (if improvements found)
- **Checkpoint**: true (only if proposals are generated)
- **On failure**: log and continue (non-blocking)
- **Description**: Analyze the completed run. Pay special attention to whether the refactoring plan was accurate and whether the verification step caught any issues.

---

## Dependency Graph

```
Step 1 (Analyze) ──── [checkpoint]
    │
Step 2 (Review Plan) ──── [checkpoint]
    │
Step 3 (Execute Refactoring) ──── Step 4 (Verify)
                                       │
                                  Step 5 (Docs)
                                       │
                                  Step 6 (Retrospective)
```

## Feedback Loops

1. **Review → Analysis**: If the reviewer rejects the refactoring plan, the analysis re-runs with feedback. Capped at 3 cycles.

2. **Verification → Refactoring**: If existing tests fail after refactoring, the implementer re-runs with the failures. Capped at 3 cycles.

## Git Operations

Git is handled by the orchestrator, not by individual agents:

- **Before Step 1**: Create branch `refactor/{run-id}` from the current branch (when `branch_strategy: feature-branches`)
- **After Step 4 (Verification passes)**: Stage and commit: `"refactor: {description from refactoring plan}"`
- **After Step 5 (Documentation)**: Stage and commit docs + knowledge base changes: `"docs: update documentation after refactoring"`
