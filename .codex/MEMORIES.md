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

<!-- Add new entries below this line using the Entry Format above. -->
