# Bugfix Workflow

## Paths

All artifact paths in this workflow are relative to the run directory: `.sdlc/runs/{run-id}/`.
For example, `artifacts/bugfix/analysis.md` resolves to `.sdlc/runs/{run-id}/artifacts/bugfix/analysis.md`.
The knowledge base (`knowledge/`) is shared across runs and lives at `.sdlc/knowledge/`.

## Trigger

Fixing a bug in an existing codebase. The user reports something broken, a test failure, an error, or references a known issue.

Signals: "fix", "bug", "broken", "doesn't work", "error", "crash", "regression", issue reference, stack trace provided.

## Step Skipping

Any step can be skipped if its expected output artifacts already exist in the run directory before execution begins. The orchestrator detects pre-existing artifacts and marks the step as `skipped`. This allows users to provide their own PRD, architecture, or other artifacts and start the workflow mid-stream.

---

## Steps

### Step 1: Analyze Bug

- **ID**: bug-analysis
- **Agent**: implementer
- **Inputs**: User's bug report, `knowledge/known-issues.md` (if present), `knowledge/architecture.md`, `knowledge/components/`, source code
- **Outputs**: `artifacts/bugfix/analysis.md`
- **Checkpoint**: true
- **On failure**: escalate
- **Description**: Reproduce the bug and diagnose the root cause. Read the existing knowledge base for context on the affected area. The analysis must include: reproduction steps, root cause identification, affected components, and a proposed fix approach. Do not fix anything yet — only diagnose.
- **Special instructions**: The implementer runs in diagnostic mode. Its prompt includes: "You are diagnosing a bug, not implementing a feature. Reproduce the issue first, then trace through the code to find the root cause. Do not modify any source files. Write your findings to the analysis document."

---

### Step 2: Implement Fix

- **ID**: fix-implementation
- **Agent**: implementer
- **Depends on**: bug-analysis
- **Inputs**: `artifacts/bugfix/analysis.md`, `knowledge/conventions.md`, `knowledge/components/`, source code
- **Outputs**: modified source code, `artifacts/implementation/progress.md`
- **Checkpoint**: false
- **On failure**: retry(3), then escalate
- **Description**: Apply the targeted fix identified in the analysis. Keep changes minimal and focused — fix the bug without refactoring unrelated code. The progress report should list exactly which files were changed and why.

---

### Step 3: Verify Fix

- **ID**: verification
- **Agent**: tester (mode: execution)
- **Depends on**: fix-implementation
- **Inputs**: `artifacts/bugfix/analysis.md`, `artifacts/implementation/progress.md`, source code, existing test suites
- **Outputs**: `artifacts/testing/test-results.md`
- **Checkpoint**: false
- **On failure**: Route `artifacts/testing/test-results.md` to step `fix-implementation`. Re-run step `fix-implementation` with test failures as input.
- **Description**: Verify the fix by running three categories of tests: (1) a new test that reproduces the original bug and confirms it is resolved, (2) tests for the affected component to ensure correctness, and (3) the full existing test suite to catch regressions. All three must pass.

---

### Step 4: Update Documentation

- **ID**: documentation
- **Agent**: documenter
- **Depends on**: verification
- **Inputs**: `artifacts/bugfix/analysis.md`, `artifacts/implementation/progress.md`, `artifacts/testing/test-results.md`, `knowledge/known-issues.md`, source code
- **Outputs**: updated `knowledge/known-issues.md`, updated files in `knowledge/` (if the bug revealed architectural gaps)
- **Checkpoint**: false
- **On failure**: retry(2), then escalate
- **Description**: Update the known-issues file — remove the entry if the bug was listed, or add a note about the fix if it was a newly discovered issue. If the bug revealed undocumented behavior or architectural gaps, update the relevant knowledge base files.

---

### Step 5: Retrospective

- **ID**: retrospective
- **Agent**: retrospective
- **Depends on**: documentation
- **Inputs**: `telemetry.json` (in the run directory), all artifacts, current framework files
- **Outputs**: `artifacts/evolution/proposal-{date}.md` (if improvements found)
- **Checkpoint**: true (only if proposals are generated)
- **On failure**: log and continue (non-blocking)
- **Description**: Analyze the completed run for improvement opportunities. Pay particular attention to whether the bug could have been caught by better testing or architecture in the original workflow.

---

## Dependency Graph

```
Step 1 (Bug Analysis) ──── [checkpoint]
    │
Step 2 (Implement Fix)
    │
Step 3 (Verify Fix)
    │    │
    │  [feedback loop]
    │
Step 4 (Update Docs)
    │
Step 5 (Retrospective) ──── [checkpoint if proposals]
```

## Feedback Loops

This workflow has one feedback loop:

1. **Verification → Fix Implementation**: If the fix introduces regressions or fails to resolve the original bug, the implementer re-runs with the test results. Capped at 3 cycles.

Total retries cannot exceed the `max_retries_per_step` setting.

## Git Operations

Git is handled by the orchestrator, not by individual agents:

- **Before Step 1**: Create branch `fix/{run-id}` from the current branch (when `branch_strategy: feature-branches`)
- **After Step 3 (Verification passes)**: Stage and commit the fix: `"fix: {bug description from analysis}"`
- **After Step 4 (Documentation)**: Stage and commit docs + knowledge base changes: `"docs: update documentation for {fix}"`
