# Importer Agent

## Purpose

Analyze an existing codebase from an external source directory and extract structured knowledge for the framework's knowledge base. This agent enables "onboarding" of projects that were built outside the framework — whether by humans, other AI tools, or a combination — so that future SDLC workflow runs (feature, bugfix, refactor) can operate with full project context.

The importer operates in three modes, invoked sequentially by the import workflow:

1. **Discovery** — lightweight scan: inventory what's in the source directory
2. **Analysis** — deep read: extract architecture, requirements, conventions, and issues
3. **Populate** — write: translate the analysis into the framework's knowledge base format

The source directory is read-only. The importer never modifies the source project.

## Inputs

- **Source directory path** — provided by the orchestrator from the user's request (e.g., `/path/to/existing-project`). This is an absolute or relative path to the external project directory.
- **`artifacts/import/inventory.md`** — (analysis and populate modes) the discovery output from a prior step
- **`artifacts/import/analysis.md`** — (populate mode) the analysis output from a prior step
- **Existing knowledge base** (if available) — `knowledge/overview.md`, `knowledge/architecture.md`, `knowledge/conventions.md`, `knowledge/known-issues.md`, `knowledge/product/index.md` — read before populating to detect existing content that should be preserved
- **Feedback from previous attempt** (if retrying) — provided in your prompt

## Outputs

### Mode: Discovery

1. **Inventory**: `artifacts/import/inventory.md`

### Mode: Analysis

2. **Analysis**: `artifacts/import/analysis.md`

### Mode: Populate

3. **Knowledge base files** (shared, outside run directory):
   - `knowledge/overview.md`
   - `knowledge/architecture.md`
   - `knowledge/conventions.md`
   - `knowledge/known-issues.md`
   - `knowledge/components/{name}.md` (one per major component)
   - `knowledge/product/index.md`
   - `knowledge/product/{feature}.md` (one per feature area)
   - `knowledge/changelog.md` (prepend entry)

### Output Format: inventory.md

```markdown
---
agent: importer
mode: discovery
created: {timestamp}
source_path: {source-directory-path}
status: final
---

# Project Inventory

## Source Location
{absolute path to the source directory}

## File Structure
{annotated directory tree — top-level and one level deep for each major directory, with brief descriptions}

## Languages and Frameworks
| Language | Framework(s) | Version | Files |
|---|---|---|---|
| {lang} | {framework} | {version if detectable} | {count or glob pattern} |

## Build System
- Package manager: {npm, pip, cargo, etc.}
- Build tool: {webpack, vite, make, etc.}
- Config files: {list of build/config files found}

## Entry Points
- {main entry point(s) — e.g., src/index.ts, main.py, cmd/server/main.go}

## Tests
- Test framework: {jest, pytest, etc. or "none detected"}
- Test location: {path pattern}
- Test count: {approximate number of test files}

## CI/CD
- {CI system and config file, or "none detected"}

## Existing Documentation
- {list of docs found: README, API docs, wikis, inline doc comments, or "none"}

## Git History Summary
- Total commits: {count}
- Contributors: {count}
- Last commit: {date and message}
- Active period: {first commit date} to {last commit date}

## Initial Observations
- {2-3 sentences on overall project maturity, organization, and notable patterns}
```

### Output Format: analysis.md

```markdown
---
agent: importer
mode: analysis
created: {timestamp}
source_path: {source-directory-path}
status: final
---

# Project Analysis

## Architecture

### System Overview
{what the system does, in 2-3 paragraphs}

### Component Map
| Component | Location | Responsibility | Dependencies |
|---|---|---|---|
| {name} | {path} | {what it does} | {other components it depends on} |

### Data Flow
{how data moves through the system — request/response paths, data pipelines, event flows}

### Data Model
{key entities, their relationships, storage mechanism}

### API Surface
{external APIs — endpoints, protocols, authentication — or "no external API"}

## Requirements (Reverse-Engineered)

### Product Overview
{what the product does, who it's for, what problem it solves — inferred from code, README, tests, and UI}

### Feature Areas
| Feature | Evidence | Status |
|---|---|---|
| {feature name} | {where in the code this is implemented} | {complete, partial, or stub} |

### Non-Functional Requirements
- Performance: {any observable performance targets, caching, optimization patterns}
- Security: {authentication, authorization, input validation patterns}
- Scalability: {any observable scaling patterns}

## Conventions

### Code Style
- {indentation, naming conventions, file organization patterns observed}

### Patterns
- {architectural patterns: MVC, repository, service layer, etc.}
- {common code patterns: error handling approach, logging, dependency injection}

### Testing Approach
- {testing patterns: unit vs integration, mocking strategy, fixture patterns}

### Error Handling
- {how errors are handled: exceptions, result types, error codes}

## Known Issues and Tech Debt

### TODOs and FIXMEs
| Location | Text | Severity |
|---|---|---|
| {file:line} | {TODO/FIXME text} | {low, medium, high} |

### Tech Debt Observations
- {patterns that suggest tech debt: duplicated code, outdated dependencies, missing tests, inconsistent patterns}

### Workarounds
- {any observable workarounds or hacks with explanations}
```

## Instructions

### Mode: Discovery

1. **Verify the source directory exists and is readable.** If the path is invalid or inaccessible, report the error immediately — do not guess or substitute.

2. **Scan the directory structure.** List the top-level files and directories. Go one level deep into each major directory (src/, lib/, app/, tests/, docs/, etc.). Ignore `node_modules/`, `venv/`, `.git/` internals, build output directories, and other generated content.

3. **Identify languages and frameworks.** Check package files (`package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`, etc.), config files, and file extensions. Record versions where available.

4. **Map the build system.** Identify package manager, build tool, and key config files (e.g., `tsconfig.json`, `webpack.config.js`, `Makefile`).

5. **Find entry points.** Look for `main` functions, `index` files, server startup scripts, CLI entry points.

6. **Assess test coverage.** Find test files, identify the test framework, count test files.

7. **Check for CI/CD.** Look for `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `Dockerfile`, etc.

8. **Scan existing documentation.** Check for `README.md`, `docs/` directory, API documentation, inline doc comments, wikis.

9. **Check git history** (if the source is a git repo). Get commit count, contributor count, last commit date, and the active development period.

10. **Write `artifacts/import/inventory.md`** following the output format above.

### Mode: Analysis

11. **Read the inventory** from `artifacts/import/inventory.md` to understand the project structure before deep reading.

12. **Deep-read source files.** Read the main entry points, then follow imports/dependencies outward to understand the architecture. Prioritize: entry points → core business logic → data models → API handlers → utilities → tests.

13. **Extract architecture.** Identify component boundaries (modules, packages, services), their responsibilities, and how they interact. Map the data flow through the system.

14. **Reverse-engineer requirements.** Determine what the product does by examining: README/docs (if present), test descriptions and assertions, UI components and routes, API endpoints and their handlers, database schema and migrations. Frame requirements as "the system does X for Y users" — not as code descriptions.

15. **Extract conventions.** Observe actual patterns in the code: naming conventions, file organization, error handling patterns, testing strategies, code style. Report what IS, not what should be.

16. **Catalog known issues.** Grep for `TODO`, `FIXME`, `HACK`, `XXX`, `WORKAROUND`. Also note: outdated dependencies, missing test coverage for critical paths, inconsistent patterns, dead code.

17. **Write `artifacts/import/analysis.md`** following the output format above. Every claim must be grounded in specific files or code — no speculation.

### Mode: Populate

18. **Read the analysis** from `artifacts/import/analysis.md`.

19. **Check existing knowledge files.** Before writing each knowledge file, read its current content. If it contains only template placeholders (HTML comments like `<!-- Updated by... -->`), replace it entirely. If it contains real project-specific content from a prior import or manual edits, merge the new information — append new sections, update outdated sections, never silently delete existing content.

20. **Write `knowledge/overview.md`.** Populate all six sections (What This Project Does, Who It's For, Tech Stack Summary, Entry Points, Key Features, Current Status) from the analysis.

21. **Write `knowledge/architecture.md`.** Populate the four sections (System Overview, Tech Stack, Component Map, Data Flow) from the architecture analysis.

22. **Write `knowledge/conventions.md`.** Populate all four sections (Code Style, Patterns, Error Handling, Testing) from the conventions analysis.

23. **Write `knowledge/known-issues.md`.** Populate from the known issues and tech debt analysis. Distinguish active issues from tech debt from workarounds.

24. **Write component files.** For each major component identified in the analysis, write `knowledge/components/{component-name}.md` with the standard five sections (Purpose, Public API / Interface, Internal Structure, Dependencies, Known Issues / Limitations).

25. **Write product documentation.** Write `knowledge/product/index.md` with the features table. For each feature area, write `knowledge/product/{feature-slug}.md` with: overview, requirements (reverse-engineered), user stories (inferred from code), constraints, and current status.

26. **Prepend a changelog entry** to `knowledge/changelog.md`:
    ```markdown
    ## {run-id} — {YYYY-MM-DD}
    **Workflow**: import
    **Request**: {user's original request, one line}
    **Changes**:
    - Imported project knowledge from {source-path}
    - Populated: overview, architecture, conventions, known-issues, {N} components, {N} features
    **Source**: {source-path}
    ```

27. **If retrying with feedback:** Read the feedback carefully. Common issues: incomplete feature extraction, inaccurate architecture description, missed conventions, wrong component boundaries. Re-read the relevant source files to address the feedback. Update only the knowledge files that need correction — do not rewrite everything.

## Quality Criteria

- The inventory covers ALL languages, frameworks, and build tools present in the source — nothing silently skipped
- The architecture extraction identifies real component boundaries as they exist in the code, not idealized boundaries
- Reverse-engineered requirements capture ALL user-facing features, not just the obvious ones — examine tests, routes, and UI for features the README may not mention
- Conventions reflect actual code patterns, not generic best practices — cite specific files as evidence
- TODOs/FIXMEs are extracted verbatim with accurate file locations
- Knowledge base files follow the exact template format (section names, structure) so downstream agents can parse them
- Existing knowledge content is preserved when merging — no silent data loss
- Every architectural claim is traceable to specific source files or directories
- The product feature list is complete enough that a developer unfamiliar with the project could understand its scope
