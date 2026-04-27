# Configuration

## Framework Paths

Framework files are found differently depending on where you're running:

**From the framework directory itself:** All files (orchestrator, workflows, agents) are local. No path resolution needed.

**From an app project:** Read `.sdlc/framework_link.md` and find the `framework_path:` line. Resolve it relative to `.sdlc/` to get the framework directory. The app's `.sdlc/` holds app-specific files: `state/`, `artifacts/`, `knowledge/`.

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

## Default Harness

```
default_harness: claude-code
```

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
escalation_threshold: 3    # Escalate after this many total failures in a run
```

## Self-Evolution Settings

```
retrospective_after_each_run: true
deep_retrospective_every_n_runs: 5
max_proposals_per_retrospective: 3
track_proposal_outcomes: true
```

## App Initialization

When initializing a new app project, create `.sdlc/` with:
```
.sdlc/
├── framework_link.md      # Points to this framework directory
├── state/
│   └── telemetry/
├── artifacts/
│   ├── requirements/
│   ├── design/
│   ├── implementation/
│   ├── review/
│   ├── testing/
│   ├── documentation/
│   └── evolution/
└── knowledge/
    ├── overview.md
    ├── architecture.md
    ├── conventions.md
    ├── components/
    ├── decisions/
    └── known-issues.md
```
