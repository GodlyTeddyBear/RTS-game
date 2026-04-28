# Screen Templates and Controllers

This document defines how to structure screen-level files so composition stays readable and orchestration stays testable.

---

## Related Docs

- [LAYERS.md](LAYERS.md) for frontend layer boundaries.
- [HOOKS.md](HOOKS.md) for read hooks, write hooks, ViewModels, and controller hooks.
- [COMPONENTS.md](COMPONENTS.md) for the Atomic Design hierarchy.
- [ANIMATION_PATTERN.md](ANIMATION_PATTERN.md) for animation-heavy wrapper splits.
- [UDIM_LAYOUT_RULES.md](UDIM_LAYOUT_RULES.md) for layout and positioning rules.

---

## Purpose

- A screen file should be an integration template, not a behavior-heavy component.
- Feature screens live in `Presentation/Templates/`.
- App-level router-owned screens may live in `App/Presentation/Screens/`.
- Regardless of folder name, the same composition and controller rules apply.

Use this split:

- `Presentation/Templates/[Screen].lua` or `App/Presentation/Screens/[Screen].lua` for composition and prop wiring
- `Application/Hooks/use[Screen]Controller.lua` for local UI state and side-effect orchestration
- `Application/ViewModels/` only when display formatting or derived values become non-trivial

This screen-level pattern can coexist with the animated component wrapper/controller/view pattern inside the same feature.

---

## Screen File Responsibilities

- Compose child components and wire props.
- Call hooks and pass returned values and actions down.
- Keep root frame and layout setup near the render tree.

## Screen File Non-Responsibilities

- Do not contain complex orchestration, such as timers, chained side effects, or navigation sequencing.
- Do not own business or data formatting logic.
- Do not call infrastructure services directly from the render file.
- Do not orchestrate animation primitives directly, such as `TweenService:Create`, `spr.target`, or transition sequencing via `task.delay` and `task.wait`.
- Prefer animation hooks and abstractions such as `useScreenTransition`, `useSpring`, `useTween`, `useStaggeredMount`, and `useHoverSpring` from Application.

---

## Controller Hook Responsibilities

- Own local UI interaction state for the screen.
- Expose a small callback surface for child components.
- Coordinate side effects such as sound, delayed navigation, and flow transitions.
- Keep the hook body small and use module-level helpers for behavior.

---

## Animated Component Split

When an organism has meaningful animation behavior, split it into three files:

- `Presentation/Organisms/[Component].lua` - thin wrapper that wires controller and view
- `Application/Hooks/use[Component]Controller.lua` - refs, motion hooks, animation orchestration, event composition
- `Presentation/Organisms/[Component]View.lua` - pure render tree with no orchestration hooks

Example:

- `SidePanel.lua` wraps
- `useSidePanelController.lua` handles spring, reduced-motion, and hover logic
- `SidePanelView.lua` renders only from props

This keeps render files declarative while preserving rich motion behavior.

---

## Practical Heuristic

- If a screen has more than simple composition, extract that behavior into `use[Screen]Controller.lua`.
- "More than simple composition" means more than a couple handlers, delayed tasks, or chained side effects.

---

## Checklist

- [ ] `Presentation/Templates/[Screen].lua` or `App/Presentation/Screens/[Screen].lua` is mostly declarative composition.
- [ ] Interaction and orchestration logic live in `Application/Hooks/use[Screen]Controller.lua`.
- [ ] Child components receive only render-ready values and callbacks.
- [ ] Derived display formatting is moved to a ViewModel when it grows.
- [ ] Screen render files avoid direct atom and service calls.
- [ ] Screen render files avoid direct animation primitive orchestration.
- [ ] Animated organisms with complex motion use a wrapper, controller, and view split.
