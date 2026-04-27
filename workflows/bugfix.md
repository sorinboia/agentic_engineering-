# Bugfix Workflow

## Trigger

Fixing a bug in an existing codebase. The user reports something broken, a test failure, an error, or references a known issue.

Signals: "fix", "bug", "broken", "doesn't work", "error", "crash", "regression", issue reference, stack trace provided.

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
- **Agent**: tester
- **Depends on**: fix-implementation
- **Inputs**: `artifacts/bugfix/analysis.md`, `artifacts/implementation/progress.md`, source code, existing test suites
- **Outputs**: `artifacts/testing/test-results.md`
- **On failure**: Route `artifacts/testing/test-results.md` to fix-implementation step. Re-run implementer with test failures as input.
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
- **Inputs**: `state/telemetry/run-{id}.json`, all artifacts, current framework files
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
