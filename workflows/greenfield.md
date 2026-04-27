# Greenfield Workflow

## Paths

All artifact paths in this workflow are relative to the run directory: `.sdlc/runs/{run-id}/`.
For example, `artifacts/requirements/prd.md` resolves to `.sdlc/runs/{run-id}/artifacts/requirements/prd.md`.
The knowledge base (`knowledge/`) is shared across runs and lives at `.sdlc/knowledge/`.

## Trigger

New project creation — no existing codebase. The user wants to build something from scratch.

Signals: "create", "build", "new app", "make me a", "start from scratch", empty or nonexistent source directory.

---

## Steps

### Step 1: Create PRD

- **ID**: prd-creation
- **Agent**: prd-creator
- **Inputs**: User's original request
- **Outputs**: `artifacts/requirements/prd.md`
- **Checkpoint**: true
- **On failure**: escalate
- **Description**: Transform the user's idea into a structured Product Requirements Document. This is the foundation — everything downstream depends on its quality.

---

### Step 2: Design Architecture

- **ID**: architecture
- **Agent**: architect
- **Depends on**: prd-creation
- **Inputs**: `artifacts/requirements/prd.md`
- **Outputs**: `artifacts/design/architecture.md`, `artifacts/design/tech-decisions.md`
- **Checkpoint**: true
- **On failure**: escalate
- **Description**: Design the system architecture, choose technologies, define the project structure, and document key technical decisions.

---

### Step 3a: Implement

- **ID**: implementation
- **Agent**: implementer
- **Depends on**: architecture
- **Inputs**: `artifacts/requirements/prd.md`, `artifacts/design/architecture.md`, `artifacts/design/tech-decisions.md`
- **Outputs**: source code in project directory, `artifacts/implementation/progress.md`
- **Checkpoint**: false
- **On failure**: retry(3), then escalate
- **Description**: Write the actual code. Create the project structure, implement all features defined in the PRD, following the architecture and tech decisions.

---

### Step 3b: Write Test Plan

- **ID**: test-planning
- **Agent**: tester
- **Depends on**: architecture
- **Inputs**: `artifacts/requirements/prd.md`, `artifacts/design/architecture.md`
- **Outputs**: `artifacts/testing/test-plan.md`
- **Parallel with**: implementation
- **On failure**: retry(2), then escalate
- **Description**: Design the test strategy and write a detailed test plan based on the requirements and architecture. Runs in parallel with implementation.

---

### Step 4: Review Implementation

- **ID**: review
- **Agent**: reviewer
- **Depends on**: implementation
- **Inputs**: `artifacts/requirements/prd.md`, `artifacts/design/architecture.md`, `artifacts/implementation/progress.md`, source code
- **Outputs**: `artifacts/review/feedback.md`
- **On failure**: escalate
- **On rejection**: Route `artifacts/review/feedback.md` back to implementation step as additional input. Re-run implementer with the feedback.
- **Description**: Review the implementation against the PRD and architecture. Check for correctness, completeness, code quality, and security.

---

### Step 5: Run Tests

- **ID**: testing
- **Agent**: tester
- **Depends on**: implementation, test-planning
- **Inputs**: source code, `artifacts/testing/test-plan.md`
- **Outputs**: `artifacts/testing/test-results.md`
- **On failure**: Route `artifacts/testing/test-results.md` to implementation step. Re-run implementer with test failures as input.
- **Description**: Write and execute tests based on the test plan. Report results including coverage and any failures.

---

### Step 6: Write Documentation

- **ID**: documentation
- **Agent**: documenter
- **Depends on**: implementation, testing
- **Inputs**: all artifacts, source code
- **Outputs**: `artifacts/documentation/`, `knowledge/`
- **Checkpoint**: false
- **On failure**: retry(2), then escalate
- **Description**: Write user-facing documentation and update the project knowledge base for future agent sessions.

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
Step 1 (PRD) ──── [checkpoint]
    │
Step 2 (Architecture) ──── [checkpoint]
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

2. **Testing → Implementation**: If tests fail, the implementer re-runs with the failure details. Capped at 3 cycles.

Both loops share the same retry budget — total retries across both loops cannot exceed the `max_retries_per_step` setting.
