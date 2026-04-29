# MEMORIES

This file is for project-specific lessons learned that should be followed in future work, but do not belong in architecture, coding-style, or feature docs.

## Use This For

- Repeated mistakes and the rule that prevents them.
- Workflow lessons that save time or avoid regressions.
- Practical guardrails discovered during implementation/debugging.

## Do Not Use This For

- Permanent architecture decisions (put those in `.codex/documents/architecture/`).
- Coding standards (put those in `.codex/documents/coding-style/`).
- Feature requirements or specs (put those near the feature/context docs).

## Entry Format

Use this template for each new memory:

```md
## [YYYY-MM-DD] Short Rule Name

Context: What happened.
Rule: What must be done going forward.
Why: What breaks or regresses if ignored.
Applies To: Files/contexts/systems affected.
```

---

## Memories

## [2026-04-16] Center UIListLayout For Hover-Scaled Buttons

Context: Buttons inside a `UIListLayout` used hover scale effects, but they only appeared to expand toward the right side.
Rule: When a `UIListLayout` contains buttons that use hover scaling/effects, set the layout alignment properties to centered so scaling appears balanced on both sides.
Why: Non-centered alignment makes hover scaling look one-sided (right-biased) instead of expanding from the center.
Applies To: Roblox UI screens/panels using `UIListLayout` with interactive button hover scale effects.

## [2026-04-26] Preference for multiple files instead of one

Context: Behavior trees and everything related was created using one file, which was the combat behavior runtime service.
This isn't ideal because the file has multiple responsibilities.
The solution was to separate into a new infrastructure folder that contains individual behaviors, and then the runtime service just requires and constructs them without knowing the individual specifics

## [2026-04-29] Prefer Shared Spatial and Model Utilities

Context: Shared helpers now cover common spatial lookup, placement candidate generation, and model pivot or bounds work.
Rule: Prefer `SpatialQuery`, `PlacementPlus`, and `ModelPlus` before writing new ad hoc spatial math, placement validation, raycast helpers, or model traversal code.
Why: These utilities keep placement, targeting, and model handling consistent and avoid duplicated technical logic across contexts.
Applies To: Backend and frontend contexts, placement flows, combat and targeting flows, and any code that works with model transforms or spatial queries.

<!-- Add new entries below this line using the Entry Format above. -->
