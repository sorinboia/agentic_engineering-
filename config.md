# Configuration

## Framework Paths

Project-level overrides can be placed in `.sdlc/overrides/`. See the orchestrator's 'Project Overrides' section for details.

Framework files are found differently depending on where you're running:

**From the framework directory itself:** All files (orchestrator, workflows, agents) are local. No path resolution needed.

**From an app project:** Read `.sdlc/framework_link.md` and find the `framework_path:` line. Resolve it relative to `.sdlc/` to get the framework directory. The app's `.sdlc/` holds per-run data in `runs/{run-id}/` and the shared knowledge base in `knowledge/`.

## Harness Adapters

The orchestrator spawns agents using harness CLI tools. Each adapter defines the command template.

### Claude Code (Default)

```
command: claude -p "{prompt}" --allowedTools Bash,Read,Write,Edit
working_directory: {app_root}
supports_parallel: true
```

### Codex CLI

```
command: codex -q "{prompt}"
working_directory: {app_root}
supports_parallel: true
```

### Custom Harness

```
command: {custom_command} "{prompt}"
working_directory: {app_root}
supports_parallel: false
```

To add a new harness, copy one of the templates above and fill in the command pattern.
The `{prompt}` placeholder is replaced with the constructed agent prompt.
The `{app_root}` placeholder is replaced with the app project's root directory.

A custom harness must:
- Accept a text prompt as a command-line argument (the `{prompt}` placeholder)
- Execute in the specified working directory
- Be able to read files from the project directory and `.sdlc/`
- Be able to write files to the project directory and `.sdlc/`
- Exit with code 0 on success, non-zero on failure
- Complete within the `step_timeout` defined in Error Handling (subprocess mode only)

## Default Harness

```
default_harness: claude-code
```

**Note on model selection:** This framework does not configure which AI model to use — that is controlled by the harness itself (e.g., Claude Code's `--model` flag, or the model configured in the Codex CLI). To use different models for different agents, use subprocess mode with `step_harness_overrides` and configure each harness instance's model separately.

### Per-Step Harness Override

Individual workflow steps can specify a different harness:
```
step_harness_overrides:
  # Example: use codex for implementation, claude for everything else
  # implementation: codex
```

## Execution Mode

```
default_execution_mode: inline
```

Options:
- `inline` — the orchestrator session acts as all agents sequentially within one session. Default for interactive use.
- `subprocess` — the orchestrator spawns separate harness CLI sessions per agent. Required for parallel execution across different harnesses or different models per step.

## Git Settings

```
git_integration: true
branch_strategy: feature-branches
```

Options for `branch_strategy`:
- `feature-branches` — feature/bugfix/refactor workflows create branches. Default.
- `trunk` — all commits go directly to the current branch. No branch creation.

When `git_integration` is `false`, the orchestrator skips all git operations.

## Autonomy Settings

Controls when the orchestrator pauses for user review.

```
default_autonomy: checkpoint
```

Options:
- `autonomous` — never pause, run all steps automatically
- `checkpoint` — pause at steps marked with `checkpoint: true` in the workflow
- `supervised` — pause after every step for user review

### Per-Step Overrides

```
step_autonomy:
  prd-creation: checkpoint
  architecture: checkpoint
  implementation: autonomous
  review: autonomous
  testing: autonomous
  documentation: autonomous
```

## Error Handling

```
max_retries_per_step: 3
escalation_threshold: 3    # Escalate the entire run after this many total step failures (across all steps)
step_timeout: 300          # Seconds. Kill a subprocess agent if it exceeds this. Only applies in subprocess mode.
```

- `max_retries_per_step`: Maximum retries for a single step before escalating that step.
- `escalation_threshold`: Total failure count across ALL steps in a run. When reached, escalate the entire run regardless of per-step retry budgets. See orchestrator's "Escalation Threshold" section.
- `step_timeout`: Subprocess mode only. If a spawned agent session exceeds this duration, kill it and treat the step as failed. Inline mode is not subject to timeouts (the orchestrator controls its own execution).

## Self-Evolution Settings

```
retrospective_after_each_run: true
deep_retrospective_every_n_runs: 5
max_proposals_per_retrospective: 3
track_proposal_outcomes: true
```

- `retrospective_after_each_run`: If true, the retrospective agent runs after every workflow completion. If false, retrospectives are skipped entirely.
- `deep_retrospective_every_n_runs`: The orchestrator counts completed runs in `.sdlc/runs/index.md`. When the count is a multiple of this value, the retrospective runs in deep mode (analyzing trends across the last N runs). See orchestrator's "Post-Workflow" section.
- `max_proposals_per_retrospective`: The retrospective agent produces at most this many evolution proposals per run.
- `track_proposal_outcomes`: If true, the orchestrator logs user decisions (approved/rejected/deferred) for each proposal to `.sdlc/knowledge/decisions/proposal-log.md`. The retrospective agent reads this log to avoid re-proposing rejected changes.

## App Initialization

When initializing a new app project, create `.sdlc/` with:
```
.sdlc/
├── framework_link.md      # Points to this framework directory
├── runs/                  # Empty at init; populated per-run at runtime
│                          # Each run creates: runs/{run-id}/state.json,
│                          #   telemetry.json, and artifacts/ subdirectories
└── knowledge/
    ├── overview.md
    ├── architecture.md
    ├── conventions.md
    ├── components/
    ├── decisions/            # Proposal tracking log and ADRs
    │   └── proposal-log.md   # Created by orchestrator when track_proposal_outcomes is true
    ├── product/              # Living product requirements
    │   └── index.md
    ├── changelog.md
    └── known-issues.md
```
