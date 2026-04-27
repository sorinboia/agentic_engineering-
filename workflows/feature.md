# Feature Workflow

## Paths

All artifact paths in this workflow are relative to the run directory: `.sdlc/runs/{run-id}/`.
For example, `artifacts/requirements/feature-spec.md` resolves to `.sdlc/runs/{run-id}/artifacts/requirements/feature-spec.md`.
The knowledge base (`knowledge/`) is shared across runs and lives at `.sdlc/knowledge/`.

## Trigger

Adding a feature to an existing codebase. The user wants to extend or enhance a project that already has source code, architecture, and a knowledge base.

Signals: "add", "implement", "new feature", "extend", "enhance", existing codebase present in the project directory.

---

## Steps

### Step 1: Gather Requirements

- **ID**: requirements-gathering
- **Agent**: prd-creator
- **Inputs**: User's feature request, `knowledge/overview.md`, `knowledge/architecture.md`, `knowledge/conventions.md`, existing `artifacts/requirements/prd.md` (if present)
- **Outputs**: `artifacts/requirements/feature-spec.md`
- **Checkpoint**: true
- **On failure**: escalate
- **Description**: Read the existing knowledge base and the user's request to produce a feature specification. This is not a full PRD from scratch — it builds on the existing project context. The spec defines what the feature does, how it integrates with existing functionality, acceptance criteria, and any constraints from the current codebase.

---

### Step 2: Design Review

- **ID**: design-review
- **Agent**: architect
- **Depends on**: requirements-gathering
- **Inputs**: `artifacts/requirements/feature-spec.md`, `knowledge/architecture.md`, `knowledge/conventions.md`, `knowledge/components/`, source code
- **Outputs**: `artifacts/design/feature-design.md`, `artifacts/design/architecture-delta.md` (if architectural changes needed)
- **Checkpoint**: true
- **On failure**: escalate
- **Description**: Evaluate whether the feature fits the existing architecture. If it does, document the integration points and implementation approach. If it does not, propose specific architectural changes in the delta document and explain why they are necessary. This is a review of the existing design, not a greenfield architecture exercise.

---

### Step 3a: Implement Feature

- **ID**: implementation
- **Agent**: implementer
- **Depends on**: design-review
- **Inputs**: `artifacts/requirements/feature-spec.md`, `artifacts/design/feature-design.md`, `artifacts/design/architecture-delta.md` (if present), `knowledge/conventions.md`, `knowledge/components/`, source code
- **Outputs**: modified source code, `artifacts/implementation/progress.md`
- **Checkpoint**: false
- **On failure**: retry(3), then escalate
- **Description**: Implement the feature within the existing codebase. Follow established conventions, integrate with existing components, and avoid unnecessary refactoring of unrelated code. The progress report should clearly distinguish new files from modified files.

---

### Step 3b: Write Test Plan

- **ID**: test-planning
- **Agent**: tester
- **Depends on**: design-review
- **Inputs**: `artifacts/requirements/feature-spec.md`, `artifacts/design/feature-design.md`, `knowledge/architecture.md`, existing test suites
- **Outputs**: `artifacts/testing/test-plan.md`
- **Parallel with**: implementation
- **On failure**: retry(2), then escalate
- **Description**: Design a test plan covering the new feature and regression tests for areas affected by the change. Identify existing tests that may need updating. Runs in parallel with implementation.

---

### Step 4: Review Implementation

- **ID**: review
- **Agent**: reviewer
- **Depends on**: implementation
- **Inputs**: `artifacts/requirements/feature-spec.md`, `artifacts/design/feature-design.md`, `artifacts/implementation/progress.md`, source code, `knowledge/conventions.md`
- **Outputs**: `artifacts/review/feedback.md`
- **On failure**: escalate
- **On rejection**: Route `artifacts/review/feedback.md` back to implementation step as additional input. Re-run implementer with the feedback.
- **Description**: Review the implementation against the feature spec and design. Verify it integrates cleanly with the existing codebase, follows conventions, and does not introduce regressions or break existing interfaces.

---

### Step 5: Run Tests

- **ID**: testing
- **Agent**: tester
- **Depends on**: implementation, test-planning
- **Inputs**: source code, `artifacts/testing/test-plan.md`, existing test suites
- **Outputs**: `artifacts/testing/test-results.md`
- **On failure**: Route `artifacts/testing/test-results.md` to implementation step. Re-run implementer with test failures as input.
- **Description**: Write and execute new feature tests and regression tests from the test plan. Run the full existing test suite to verify nothing is broken. Report results including coverage, new test count, and any regressions.

---

### Step 6: Update Documentation

- **ID**: documentation
- **Agent**: documenter
- **Depends on**: implementation, testing
- **Inputs**: `artifacts/requirements/feature-spec.md`, `artifacts/design/feature-design.md`, `artifacts/implementation/progress.md`, `artifacts/testing/test-results.md`, source code, `knowledge/`
- **Outputs**: updated files in `artifacts/documentation/`, updated files in `knowledge/`
- **Checkpoint**: false
- **On failure**: retry(2), then escalate
- **Description**: Update existing documentation to reflect the new feature. This includes user-facing docs, the knowledge base (architecture, components, conventions), and any API documentation. Do not rewrite from scratch — extend what exists.

---

### Step 7: Retrospective

- **ID**: retrospective
- **Agent**: retrospective
- **Depends on**: documentation
- **Inputs**: `telemetry.json` (in the run directory), all artifacts, current framework files
- **Outputs**: `artifacts/evolution/proposal-{date}.md` (if improvements found)
- **Checkpoint**: true (only if proposals are generated)
- **On failure**: log and continue (non-blocking)
- **Description**: Analyze the completed run for improvement opportunities. Propose changes to workflows, agents, or the framework itself.

---

## Dependency Graph

```
Step 1 (Requirements) ──── [checkpoint]
    │
Step 2 (Design Review) ──── [checkpoint]
    │
    ├─── Step 3a (Implement) ──── Step 4 (Review) ──┐
    │                                 │              │
    │                            [feedback loop]     │
    │                                                │
    └─── Step 3b (Test Plan) ─────────────────── Step 5 (Test)
                                                     │
                                                Step 6 (Docs)
                                                     │
                                                Step 7 (Retrospective) ──── [checkpoint if proposals]
```

## Feedback Loops

This workflow has two feedback loops that can trigger re-execution:

1. **Review → Implementation**: If the reviewer rejects or flags major issues, the implementer re-runs with the review feedback. Capped at 3 cycles.

2. **Testing → Implementation**: If tests fail (including regressions in the existing suite), the implementer re-runs with the failure details. Capped at 3 cycles.

Both loops share the same retry budget — total retries across both loops cannot exceed the `max_retries_per_step` setting.
