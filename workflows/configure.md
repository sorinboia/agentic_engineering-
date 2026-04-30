# Configure Workflow

## Paths

All artifact paths in this workflow are relative to the run directory: `.sdlc/runs/{run-id}/`.
For example, `artifacts/configuration/summary.md` resolves to `.sdlc/runs/{run-id}/artifacts/configuration/summary.md`.
Override files are written to `.sdlc/overrides/agents/` (project-level, outside the run directory).

## Trigger

Project configuration — the user wants to set up or update project-specific agent overrides.

Signals: "configure", "setup", "set up", "customize", "configure agents", "set conventions", "project settings", "set coding standards".

## Step Skipping

Any step can be skipped if its expected output artifacts already exist in the run directory before execution begins.

---

## Steps

### Step 1: Configure Project

- **ID**: configuration
- **Agent**: configurator
- **Inputs**: User's request, `.sdlc/overrides/agents/` (existing overrides), `knowledge/overview.md`, `knowledge/architecture.md`, `knowledge/conventions.md`, source code (if present)
- **Outputs**: `.sdlc/overrides/agents/*.md` (override files), `artifacts/configuration/summary.md`
- **Checkpoint**: true
- **On failure**: escalate
- **Description**: Interview the user about their project's coding standards, testing strategy, review criteria, documentation style, and architecture preferences. Detect existing overrides and source code to propose defaults. Generate override files for each agent where the user expressed preferences.

---

### Step 2: Validate Configuration

- **ID**: validation
- **Agent**: configurator
- **Depends on**: configuration
- **Inputs**: `.sdlc/overrides/agents/*.md` (generated overrides), `artifacts/configuration/summary.md`
- **Outputs**: `artifacts/configuration/validation.md`
- **Checkpoint**: true
- **On failure**: retry(2), then escalate
- **On rejection**: Route feedback to step `configuration`. Re-run step `configuration` with the user's revision requests.
- **Description**: Present the generated override files to the user for final review. Show each override file's content and confirm accuracy. If the user requests changes, update the override files accordingly.

---

## Dependency Graph

```
Step 1 (Configure) ──── [checkpoint]
    │
Step 2 (Validate) ──── [checkpoint]
```

## Feedback Loops

1. **Validation → Configuration**: If the user rejects the generated overrides at the validation checkpoint, the configurator re-runs step 1 with the user's feedback. Capped at 2 cycles.

## Git Operations

Git is handled by the orchestrator, not by individual agents:

- **Before Step 1**: No branch creation — configuration changes apply to the current branch directly
- **After Step 2 (Validation approved)**: Stage and commit override files and summary: `"chore: configure project agent overrides"`
