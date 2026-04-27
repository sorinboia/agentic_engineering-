# ADR-001: First Self-Evolution — Bug Patterns, Reviewer Checks, Telemetry

## Date
2026-04-27

## Context
After the first failure-recovery test run (run-20260427T112848Z, a complex chat application), the retrospective agent identified three improvement opportunities based on actual failure data: 2 implementation retries, 1 review retry, 1 testing retry.

## Decisions
1. Added a common bug pattern checklist to the implementer agent instructions
2. Made the reviewer's project validation step mandatory with specific automated checks
3. Extended the telemetry schema to capture feedback loop details (type, issue categories, resolution)

## Evidence
- 3 critical bugs caught by reviewer (pagination race condition, missing file validation, counter drift)
- 1 additional bug caught by tester (pagination cursor fallback duplicates)
- All bugs were instances of well-known patterns detectable by checklist

## Expected Impact
- Implementer retries reduced from 2+ to 0-1 per run
- Bugs caught earlier (at review rather than test time)
- Retrospective agent can analyze feedback loop patterns across runs
