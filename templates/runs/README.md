# Runs

This directory is populated at runtime. Each workflow run creates a subdirectory here:

```
runs/{run-id}/
├── state.json        # Live execution state (crash recovery, progress tracking)
├── telemetry.json    # Post-run retrospective record
└── artifacts/        # All agent outputs for this run
    ├── requirements/
    ├── design/
    ├── implementation/
    ├── review/
    ├── testing/
    ├── documentation/
    └── evolution/
```

The run ID is a UTC timestamp (e.g., `run-20260427T143022Z`). Each run is fully isolated -- its own state, telemetry, and artifacts. Multiple runs can execute concurrently without conflict.
