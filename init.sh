#!/usr/bin/env bash
#
# init.sh - Initialize an app project to use the SDLC Agent Framework
#
# Usage: ./init.sh [app-directory]
#   app-directory: path to the app project (default: current directory)
#

set -euo pipefail

# --- Resolve the framework directory (where this script lives) ---
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
# Follow symlinks to find the real location
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    # Resolve relative symlinks
    [[ "$SCRIPT_SOURCE" != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
FRAMEWORK_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# --- Resolve the app project directory ---
APP_DIR="${1:-.}"
APP_DIR="$(cd "$APP_DIR" 2>/dev/null && pwd)" || {
    echo "Error: directory '$1' does not exist." >&2
    exit 1
}

SDLC_DIR="$APP_DIR/.sdlc"
TEMPLATES_DIR="$FRAMEWORK_DIR/templates"

echo "SDLC Agent Framework — Project Init"
echo "===================================="
echo "Framework : $FRAMEWORK_DIR"
echo "App project: $APP_DIR"
echo ""

# --- 1. Create .sdlc/ directory ---
if [ -d "$SDLC_DIR" ]; then
    echo "[skip] .sdlc/ already exists"
else
    mkdir -p "$SDLC_DIR"
    echo "[create] .sdlc/"
fi

# --- 2. Copy template contents into .sdlc/ (without overwriting) ---
# We walk the template tree and copy files that don't already exist.
copy_templates() {
    local src="$1"
    local dst="$2"

    for item in "$src"/*; do
        [ -e "$item" ] || continue  # guard against empty globs
        local name
        name="$(basename "$item")"
        local target="$dst/$name"

        if [ -d "$item" ]; then
            if [ ! -d "$target" ]; then
                mkdir -p "$target"
                echo "[create] .sdlc/${target#"$SDLC_DIR"/}/"
            fi
            copy_templates "$item" "$target"
        else
            if [ -f "$target" ]; then
                echo "[skip]   .sdlc/${target#"$SDLC_DIR"/} (already exists)"
            else
                cp "$item" "$target"
                echo "[copy]   .sdlc/${target#"$SDLC_DIR"/}"
            fi
        fi
    done
}

copy_templates "$TEMPLATES_DIR" "$SDLC_DIR"

# --- 2b. Create overrides directory (optional, for project-level customizations) ---
OVERRIDES_DIR="$SDLC_DIR/overrides"
if [ -d "$OVERRIDES_DIR" ]; then
    echo "[skip]   .sdlc/overrides/ already exists"
else
    mkdir -p "$OVERRIDES_DIR/agents"
    echo "[create] .sdlc/overrides/"
    echo "[create] .sdlc/overrides/agents/"
fi

# --- 3. Update framework_link.md with the correct path ---
LINK_FILE="$SDLC_DIR/framework_link.md"

# Compute a relative path from the app's .sdlc/ dir to the framework dir.
# This keeps the setup portable (works if the whole tree moves together).
compute_relative_path() {
    # Usage: compute_relative_path <from_dir> <to_dir>
    # Both must be absolute paths.
    local from="$1"
    local to="$2"

    # Use Python if available (handles edge cases well), else fall back to
    # a pure-bash approach.
    if command -v python3 &>/dev/null; then
        python3 -c "import os.path; print(os.path.relpath('$to', '$from'))"
    elif command -v perl &>/dev/null; then
        perl -e 'use File::Spec; print File::Spec->abs2rel($ARGV[1], $ARGV[0]) . "\n"' "$from" "$to"
    else
        # Fallback: use the absolute path
        echo "$to"
    fi
}

REL_FRAMEWORK_PATH="$(compute_relative_path "$SDLC_DIR" "$FRAMEWORK_DIR")"

# Only rewrite the path line; leave the rest of the file intact.
if grep -q "^framework_path:" "$LINK_FILE" 2>/dev/null; then
    # Check if it already points to the right place
    CURRENT_PATH="$(grep "^framework_path:" "$LINK_FILE" | sed 's/^framework_path:[[:space:]]*//')"
    if [ "$CURRENT_PATH" = "$REL_FRAMEWORK_PATH" ]; then
        echo "[skip]   framework_link.md path already correct"
    else
        # Replace the framework_path line (works on both macOS and Linux sed)
        if sed --version &>/dev/null 2>&1; then
            # GNU sed
            sed -i "s|^framework_path:.*|framework_path: $REL_FRAMEWORK_PATH|" "$LINK_FILE"
        else
            # macOS BSD sed
            sed -i '' "s|^framework_path:.*|framework_path: $REL_FRAMEWORK_PATH|" "$LINK_FILE"
        fi
        echo "[update] framework_link.md -> $REL_FRAMEWORK_PATH"
    fi
fi

# --- 4. Create CLAUDE.md in the app root ---
CLAUDE_MD="$APP_DIR/CLAUDE.md"

if [ -f "$CLAUDE_MD" ]; then
    echo "[skip]   CLAUDE.md already exists"
else
    cat > "$CLAUDE_MD" << 'CLAUDE_EOF'
# SDLC Agent Framework — Orchestrator

You are the orchestrator. Your job is to EXECUTE workflows, not plan them.

## Bootstrapping

1. Read `.sdlc/framework_link.md` — find the `framework_path:` line. Resolve it relative to `.sdlc/` to get the framework directory.
2. In the framework directory, read `orchestrator.md` — it has your full instructions.
3. Read `config.md` for harness settings and autonomy levels.
4. Classify the user's intent using the orchestrator's Intent Classification table.
5. Load the matching workflow from `workflows/` and EXECUTE it:
   a. Generate a run ID and create `.sdlc/runs/{run-id}/` with artifacts subdirectories
   b. For each step: read the agent definition from `agents/`, follow its instructions, write output artifacts to the run directory
   c. Update `.sdlc/runs/{run-id}/state.json` after each step
   d. Respect checkpoint settings (pause for user review where configured)
   e. Handle errors per the orchestrator's Error Routing table
6. After all steps complete, run the retrospective agent.

## Execution Rules

- Do NOT merely plan or describe what you would do. Produce actual deliverables — real files, real code, real artifacts.
- Write all artifacts to the run directory (`.sdlc/runs/{run-id}/artifacts/`).
- Write shared knowledge updates to `.sdlc/knowledge/` (not the run directory).
- Execute inline: read each agent definition and perform the work yourself in this session.
- Follow the full pipeline start to finish. Do not stop after one step.

## Key Paths

| What | Where |
|---|---|
| Framework link | `.sdlc/framework_link.md` |
| Run state | `.sdlc/runs/{run-id}/state.json` |
| Artifacts (agent outputs) | `.sdlc/runs/{run-id}/artifacts/` |
| Telemetry | `.sdlc/runs/{run-id}/telemetry.json` |
| Knowledge base (shared) | `.sdlc/knowledge/` |
| Workflows | `{framework}/workflows/` |
| Agent definitions | `{framework}/agents/` |
| Config | `{framework}/config.md` |
CLAUDE_EOF
    echo "[create] CLAUDE.md"
fi

# --- Done ---
echo ""
echo "Done! Your project is set up."
echo ""
echo "Next steps:"
echo "  1. Review .sdlc/knowledge/overview.md and fill in your project details"
echo "  2. Run the orchestrator to start a workflow:"
echo "     claude -p \"Read CLAUDE.md and follow the framework instructions. Then: <your request>\""
echo "  3. (Optional) Add project-specific overrides in .sdlc/overrides/"
echo ""
