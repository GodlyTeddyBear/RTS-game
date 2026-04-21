# Animation Pattern

This document defines where animation logic should live in the frontend architecture.

---

## Principle

Animation is UI orchestration, not pure rendering.

- Render trees belong in Presentation view components.
- Animation timing, refs, spring calls, and reduced-motion handling belong in Application controller hooks.
- Screen/template render files should consume animation hooks; they should not orchestrate animation primitives directly.

---

## Recommended Structure

For animated organisms/components, use:
- `Presentation/Organisms/[Component].lua` (thin wrapper)
- `Application/Hooks/use[Component]Controller.lua` (animation + interaction orchestration)
- `Presentation/Organisms/[Component]View.lua` (pure render)

Example:
- `SidePanel.lua`
- `useSidePanelController.lua`
- `SidePanelView.lua`

---

## Controller Responsibilities

- Hold refs for animated targets
- Resolve reduced-motion behavior
- Trigger entrance/exit/hover/press animation hooks
- Compose stable callback handlers for the view
- Cleanup pending delayed tasks or running animations on unmount

---

## View Responsibilities

- Build the UI tree only
- Bind incoming refs and callbacks
- Avoid direct calls to sound/navigation/service hooks
- Avoid timing logic (`task.delay`, sequencing, cancellation)

---

## Common Pitfalls

- Calling action hooks (sound/navigation) directly in molecules/organisms
- Mixing heavy animation orchestration inside large render files
- Passing unused props (stale API surface)
- Recreating callback handlers every render without reason
- Direct animation primitives in screen/template files (`TweenService:Create`, `spr.target`, `spr.completed`)

---

## Checklist

- [ ] Animated component has wrapper + controller + view split
- [ ] Controller hook handles motion orchestration and cleanup
- [ ] View component is declarative and side-effect free
- [ ] Reduced-motion behavior is considered
- [ ] Screen/template files avoid direct animation primitive orchestration

---

## Enforcement

Run the guardrail check before merging UI refactors:

`powershell -ExecutionPolicy Bypass -File scripts/check-ui-animation-boundaries.ps1`

The check scans `Presentation/Screens/*.lua` and `Presentation/Templates/*.lua` for forbidden direct animation patterns and fails with a non-zero exit code when violations are found.
