---
name: roblox-migrate-utility-usage
description: Use when Codex needs to migrate one or more Roblox Luau files from ad hoc spatial math, model traversal, placement logic, or orientation helpers to the shared `SpatialQuery`, `ModelPlus`, `PlacementPlus`, and `Orient` utilities while preserving existing behavior and architecture boundaries.
---

# Roblox Migrate Utility Usage

Migrate existing utility usage without changing feature behavior or violating context boundaries. Use this skill for backend and frontend Luau modules that currently implement custom spatial query logic, model pivot/bounds traversal logic, placement candidate logic, or orientation math.

## Workflow

1. Read repo routing docs in this order: `AGENTS.md`, `.codex/MEMORIES.md`, `.codex/documents/ONBOARDING.md`.
2. Read `.codex/documents/architecture/backend/UTILITY_USE.md` before any edit.
3. Read the target file and every directly-required helper file that participates in the behavior to migrate.
4. Classify each custom block by owned utility:
- `SpatialQuery`: raycasts, overlap checks, range checks, visibility checks, nearest-candidate selection.
- `ModelPlus`: pivot, bounds, alignment, model traversal and model movement helpers.
- `PlacementPlus`: candidate generation, snapping, footprint/clearance checks, placement legality checks.
- `Orient`: look-at, facing, yaw/snap, interpolation, transform helper math.
5. Replace ad hoc technical logic with utility calls while keeping orchestration and domain decisions at the caller.
6. Preserve signatures, return contracts, events, and side-effect order unless the task explicitly allows contract changes.
7. Run targeted validation (tests, lint, or static checks available for the touched area).
8. Report exactly what was replaced, which utility now owns each behavior, and what validation was run.

## Requirements

- Preserve existing behavior and public contracts.
- Keep DDD/CQRS, ECS, persistence, and frontend boundary ownership unchanged.
- Do not move business decisions into shared utility modules.
- Do not introduce new wrapper utilities when existing shared utilities already cover the case.
- Keep changes minimal and file-local unless a shared call-site pattern requires coordinated edits.

## Reference

- Use `references/migrate-utility-usage.md` for the concrete audit checklist, replacement patterns, and output contract.
