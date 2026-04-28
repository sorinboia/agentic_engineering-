# Component Knowledge Base

This directory contains one file per major component in the project. The documenter agent creates and updates these files after each workflow run.

## Naming Convention

Files are named `{component-name}.md` (e.g., `auth-service.md`, `database.md`, `api-router.md`).

## File Structure

Each component file follows this template:

```markdown
---
component: {component-name}
updated: {timestamp}
---

# {Component Name}

## Purpose
What this component does and why it exists.

## Public API / Interface
How other parts of the system interact with this component (function signatures, endpoints, events).

## Internal Structure
Key files, classes, or modules and what they do.

## Dependencies
What this component depends on (other components, external services, libraries).

## Known Issues / Limitations
Bugs, workarounds, or technical debt specific to this component.
```
