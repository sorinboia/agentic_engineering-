# Import Workflow

## Paths

All artifact paths in this workflow are relative to the run directory: `.sdlc/runs/{run-id}/`.
For example, `artifacts/import/inventory.md` resolves to `.sdlc/runs/{run-id}/artifacts/import/inventory.md`.
The knowledge base (`knowledge/`) is shared across runs and lives at `.sdlc/knowledge/`.
The source directory is an external path provided by the user — it is read-only and never modified.

## Trigger

Importing an existing project — the user wants to onboard a codebase that was built outside the framework so that future workflows can operate with full project context.

Signals: "import", "adopt", "onboard", "bring in", "migrate from", "point to existing", path to external directory provided.

## Step Skipping

Any step can be skipped if its expected output artifacts already exist in the run directory before execution begins. The orchestrator detects pre-existing artifacts and marks the step as `skipped`. This allows users to provide their own inventory or analysis and start the workflow mid-stream.

---

## Steps

### Step 1: Discovery

- **ID**: discovery
- **Agent**: importer (mode: discovery)
- **Inputs**: Source directory path (from user's request, provided by orchestrator)
- **Outputs**: `artifacts/import/inventory.md`
- **Checkpoint**: true
- **On failure**: escalate
- **Description**: Scan the external source directory to produce a structured inventory: file tree, languages, frameworks, build system, entry points, tests, CI config, existing documentation, and git history. The user reviews the inventory to confirm what was found before committing to deep analysis.

---

### Step 2: Analysis

- **ID**: analysis
- **Agent**: importer (mode: analysis)
- **Depends on**: discovery
- **Inputs**: `artifacts/import/inventory.md`, source directory path
- **Outputs**: `artifacts/import/analysis.md`
- **Checkpoint**: false
- **On failure**: retry(3), then escalate
- **Description**: Deep-read the source codebase to extract architecture (components, data flow, API surface), reverse-engineer product requirements from code and tests, document coding conventions, and catalog known issues and tech debt. Every claim is grounded in specific source files.

---

### Step 3: Knowledge Population

- **ID**: knowledge-population
- **Agent**: importer (mode: populate)
- **Depends on**: analysis
- **Inputs**: `artifacts/import/analysis.md`, `knowledge/` (existing files, if any)
- **Outputs**: `knowledge/overview.md`, `knowledge/architecture.md`, `knowledge/conventions.md`, `knowledge/known-issues.md`, `knowledge/components/*.md`, `knowledge/product/index.md`, `knowledge/product/*.md`, `knowledge/changelog.md`
- **Checkpoint**: true
- **On failure**: retry(2), then escalate
- **Description**: Translate the analysis into the framework's knowledge base format. Write or update all living documents — overview, architecture, conventions, known issues, component docs, product feature docs, and changelog. If knowledge files already contain content, merge rather than overwrite.

---

### Step 4: Retrospective

- **ID**: retrospective
- **Agent**: retrospective
- **Depends on**: knowledge-population
- **Inputs**: `.sdlc/runs/{run-id}/telemetry.json`, `knowledge/`
- **Outputs**: `artifacts/evolution/proposal-{date}.md` (if proposals generated)
- **Checkpoint**: true (only if proposals are generated)
- **On failure**: log and continue (non-blocking)
- **Description**: Analyze the import run for quality and completeness. Propose improvements to the importer agent or import workflow if the analysis missed patterns, produced low-quality extractions, or the knowledge base format needs refinement.

---

## Dependency Graph

```
Step 1 (Discovery) ──── [checkpoint]
    │
Step 2 (Analysis)
    │
Step 3 (Knowledge Population) ──── [checkpoint]
    │
Step 4 (Retrospective) ──── [checkpoint if proposals]
```

## Feedback Loops

1. **Knowledge Population retry**: If the knowledge population step fails (e.g., malformed output, missing sections), the importer re-reads the analysis and retries. Capped at 2 cycles.

Total retries cannot exceed the `max_retries_per_step` setting.

## Git Operations

Git is handled by the orchestrator, not by individual agents:

- **Before Step 1**: Create a branch `import/{run-id}` from the current branch
- **After Step 3 (Knowledge population approved)**: Stage and commit knowledge base files: `"chore: import project knowledge from {source-path}"`
- **After Step 4 (Retrospective, if proposals approved)**: Stage and commit evolution artifacts: `"docs: retrospective for import run {run-id}"`
