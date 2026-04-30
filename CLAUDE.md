# CLAUDE.md

## What This Is

This is the SDLC Agent Framework -- a markdown-only orchestration system that drives software development workflows (greenfield, feature, bugfix, refactor, configure, import) by spawning specialized AI agents through CLI harnesses like Claude Code or Codex. The orchestrator reads a workflow definition, executes steps by invoking agents with the right context, manages state/retries/checkpoints, and runs a retrospective for self-improvement after each run.

## Directory Structure

```
orchestrator.md        Entry point. Intent classification, agent spawning, error routing,
                       checkpoint handling, crash recovery, telemetry, post-workflow logic.

config.md              Harness adapters (claude-code, codex, custom), autonomy settings,
                       retry limits, self-evolution config, app init structure.

agents/                One file per agent role. Each defines purpose, inputs, outputs,
                       instructions, and quality criteria for a single SDLC responsibility.
  prd-creator.md       Requirements gathering
  architect.md         System design and tech decisions
  implementer.md       Code generation
  reviewer.md          Code review
  tester.md            Test planning and execution
  documenter.md        Documentation and knowledge base
  retrospective.md     Post-run analysis and evolution proposals
  configurator.md    Project configuration interview and override generation
  importer.md        Analyze external codebase and populate knowledge base

workflows/             Workflow definitions. Each file is a sequence of steps with
                       dependencies, forming a DAG the orchestrator executes.
  greenfield.md        New project from scratch
  feature.md           Add feature to existing project
  bugfix.md            Diagnose and fix bugs
  refactor.md          Codebase refactoring workflow
  configure.md         Project-specific agent configuration
  import.md            Import existing project into the framework

templates/             Scaffolding copied into an app's .sdlc/ directory on init.
  framework_link.md    Config file pointing back to this framework directory
  runs/                Per-run isolation directories (populated at runtime; contains a README)
    index.md           Run history summary table maintained by the orchestrator
  knowledge/           Knowledge base templates (overview, architecture, conventions, known-issues)
    product/           Living product requirements directory
      index.md         Product overview with links to feature docs
    changelog.md       Chronological log of what changed per run
  overrides/           Project-level customization directory (created by init.sh)
    agents/            Per-project agent instruction overrides
```

## Framework Source vs App-Specific Files

This directory is the **framework source**. It contains reusable definitions: orchestrator logic, workflow DAGs, agent role definitions, and init templates. Nothing here is app-specific.

When the framework is used on an actual project, it creates a `.sdlc/` directory **inside the app's root**. That directory holds:
- `framework_link.md` -- points back to this framework directory
- `runs/` -- per-run isolation directories. Each run creates `runs/{run-id}/` containing `state.json`, `telemetry.json`, and `artifacts/` (organized by phase: requirements, design, implementation, review, testing, documentation, evolution). Multiple runs can execute concurrently without conflict.
- `knowledge/` -- persistent project knowledge base that agents read and update across runs (shared, not per-run). Includes living documents: `product/` (cumulative requirements by feature area), `architecture.md` (cumulative architecture), and `changelog.md` (chronological run log).

The orchestrator finds the framework by reading `.sdlc/framework_link.md`, then loads workflows and agents from here.

## Project Overrides

The `.sdlc/overrides/` directory allows per-project customization of agent instructions and config. Files placed in `overrides/agents/` are read by the orchestrator after the framework's agent definitions, letting projects add domain-specific constraints or modify default behavior without editing the shared framework.

## Git Integration

The orchestrator handles git operations (init, branches, commits) automatically as part of workflow execution. Each run creates a feature branch, commits artifacts at checkpoints, and can merge on completion depending on autonomy settings.

## Conventions for Agent Definitions

Each file in `agents/` defines a single agent role. Required sections:

1. **Purpose** -- what the agent does and why it matters in the pipeline.
2. **Inputs** -- what files/data the agent receives. Use artifact paths relative to the app's `.sdlc/`.
3. **Outputs** -- exact file paths the agent must write to. Include the output format (markdown with YAML frontmatter is standard).
4. **Instructions** -- numbered steps the agent follows. Be specific and actionable.
5. **Quality Criteria** -- how to evaluate whether the agent's output is good enough. These are used by the reviewer and by the orchestrator's retry logic.

Additional conventions:
- Output format blocks should show the exact markdown template with YAML frontmatter (`agent`, `created`, `status` fields).
- Instructions should address what to do when retrying with feedback from a previous attempt.
- Reference other agents' outputs by their artifact paths, not by agent name.

## Conventions for Workflow Definitions

Each file in `workflows/` defines an ordered sequence of steps forming a dependency DAG. Required fields per step:

- **ID** -- unique identifier, used in state tracking and config overrides (e.g., `prd-creation`).
- **Agent** -- which agent role to invoke (maps to `agents/{agent-name}.md`).
- **Inputs** -- artifact paths and/or data the agent needs.
- **Outputs** -- artifact paths the agent must produce.
- **On failure** -- error handling: `escalate`, `retry(N) then escalate`, or route feedback to another step.

Optional but common fields:
- **Depends on** -- step IDs that must complete first.
- **Checkpoint** -- `true` if the orchestrator should pause for user review (subject to autonomy settings in `config.md`). Must be declared on every step (use `false` if no checkpoint is needed).
- **Parallel with** -- step ID this step can run concurrently with.
- **Description** -- human-readable explanation of the step's purpose.
- **Special instructions** -- mode-specific prompt text for agents that support multiple modes (e.g., implementer in analysis mode). The orchestrator appends this to the agent's prompt.
- **On rejection** -- how to handle reviewer rejection (distinct from failure). Typically routes feedback back to a prior step by step ID for re-execution.

Workflows should also include:
- A **dependency graph** (ASCII diagram).
- A **feedback loops** section documenting any cycles (e.g., review rejects back to implementation).

## No Code to Build

All framework files are markdown. There is no source code, no build step, no compilation, no dependencies to install. The framework is consumed directly by AI harnesses that read the markdown files as prompts and instructions.

## Self-Evolution System

The retrospective agent (`agents/retrospective.md`) runs after each workflow completion. It reads run telemetry, analyzes failures/retries/user edits, and produces evolution proposals -- precise diffs to framework files (agents, workflows, config). Proposals require user approval before being applied. A deeper retrospective runs every N runs (configured in `config.md` as `deep_retrospective_every_n_runs: 5`) to detect cross-run trends and consider structural changes. The retrospective agent can also propose changes to its own instructions (meta-evolution).

## Execution Modes

The orchestrator supports two execution modes:

- **Inline (default):** The orchestrator session plays all agent roles sequentially. For each workflow step, it reads the agent definition and performs the work itself. This is the default for interactive use.
- **Subprocess:** The orchestrator spawns separate harness CLI sessions per agent (e.g., `claude -p "..."`). Used for parallel execution across different harnesses or models.

The app's `CLAUDE.md` (generated by `init.sh`) instructs the harness to use inline mode. The `default_execution_mode` setting in `config.md` controls this.
