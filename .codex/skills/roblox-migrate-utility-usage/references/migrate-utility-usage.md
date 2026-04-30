---
name: migrate-utility-usage
description: Read when executing utility-usage migrations with this skill.
---

# Migrate Utility Usage

## Audit Checklist

1. Identify the target module and all direct dependencies used by the migration path.
2. Mark ad hoc blocks by behavior type:
- spatial query behavior
- model transform/traversal behavior
- placement candidate/validation behavior
- orientation/facing behavior
3. Map each ad hoc block to one utility owner:
- `SpatialQuery`
- `ModelPlus`
- `PlacementPlus`
- `Orient`
4. Reject migration candidates that are domain ownership, lifecycle ownership, persistence ownership, or ECS ownership logic.
5. Keep any remaining domain/policy logic in the caller module.

## Replacement Contract

1. Replace only technical helper logic covered by the shared utility.
2. Preserve method names, parameters, return shape, and caller-visible behavior.
3. Preserve call order when side effects depend on sequencing.
4. Keep fallback/error behavior equivalent unless the task explicitly requests changes.
5. Avoid introducing a new intermediate helper unless two or more call sites need the same adaptation.

## Utility Mapping Guide

### SpatialQuery

Use for:
- raycast from cursor, camera, origin+direction, or model-derived origin
- overlap or occupancy checks
- range and nearest-target checks
- visibility/line-of-sight checks

Do not move:
- target eligibility policy
- combat rule outcomes
- gameplay authorization decisions

### ModelPlus

Use for:
- pivot, bounds, center, top, bottom reads
- model movement, alignment, and pivot-based transforms
- model child/descendant traversal helpers

Do not move:
- entity ownership rules
- context lifecycle behavior for runtime instances

### PlacementPlus

Use for:
- placement candidate generation from cursor/world hit
- snapping and grid/surface alignment
- footprint and clearance generation
- placement legality checks that are technical (collision/support)

Do not move:
- spending resources
- final build authorization rules
- context orchestration of placement flow

### Orient

Use for:
- look-at/facing/yaw helpers
- angle snapping or interpolation
- transform conversions and reusable CFrame orientation math

Do not move:
- AI behavior policy decisions
- state machine transitions

## Validation Checklist

- Confirm touched module compiles and requires cleanly.
- Run available tests or targeted checks for the edited subsystem.
- Verify behavior parity at the impacted call sites.
- Verify no context boundary violations were introduced.

## Output Contract

Report in this structure:

1. Files changed.
2. For each file: ad hoc block removed -> utility call added.
3. Any behaviors intentionally not migrated and why.
4. Validation commands run and outcomes.
