# Framework Link

This file connects an app's `.sdlc/` directory to the SDLC Agent Framework.

## Framework Location

framework_path: /path/to/SDLC

This path is relative to this file's directory (`.sdlc/`). Resolve it from there to find the framework root.

## How This Works

- **Reusable files** (orchestrator, workflows, agents) come from the framework directory
- **App-specific files** (state, artifacts, knowledge) live here in this `.sdlc/` directory
- The orchestrator reads this file to find the framework, then loads workflows and agent definitions from there

## Setup

When initializing a new app project:
1. Create `.sdlc/` in the app root
2. Copy the `templates/` contents from the framework into this `.sdlc/` directory
3. Update `framework_path` above to point to the framework source
4. Run the orchestrator — it will use the framework's workflows and agents with this app's local state
