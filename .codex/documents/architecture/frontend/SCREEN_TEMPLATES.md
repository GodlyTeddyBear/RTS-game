# Screen Templates and Controllers

This document defines how to structure screen-level files so composition stays readable and orchestration stays testable.

---

## Purpose

A screen file should be an integration template, not a behavior-heavy component.

Path guidance:
- Feature screens live in `Presentation/Templates/`.
- App-level router-owned screens may live in `App/Presentation/Screens/`.
- Regardless of folder name, the same composition/controller rules apply.

Use this split:
- `Presentation/Templates/[Screen].lua` (or App `Presentation/Screens/[Screen].lua`) for composition and prop wiring
- `Application/Hooks/use[Screen]Controller.lua` for local UI state and side-effect orchestration
- `Application/ViewModels/` only when display formatting or derived values become non-trivial

This screen-level pattern can coexist with the animated component wrapper/controller/view pattern inside the same feature.

---

## Screen File Responsibilities

- Compose child components and wire props.
- Call hooks and pass returned values/actions down.
- Keep root frame/layout setup near the render tree.

## Screen File Non-Responsibilities

- Do not contain complex orchestration (timers, chained side effects, navigation sequencing).
- Do not own business/data formatting logic.
- Do not call infrastructure/services directly from the render file.
- Do not orchestrate animation primitives directly (`TweenService:Create`, `spr.target`, transition sequencing via `task.delay/task.wait`).
- Prefer animation hooks and abstractions (`useScreenTransition`, `useSpring`, `useTween`, `useStaggeredMount`, `useHoverSpring`) from Application.

---

## Controller Hook Responsibilities

- Own local UI interaction state for the screen.
- Expose a small callback surface for child components.
- Coordinate side effects (sound, delayed navigation, flow transitions).

Controller hooks should keep the hook body small and use module-level helpers for behavior.

---

## Animated Component Split

When an organism has meaningful animation behavior, split it into three files:
- `Presentation/Organisms/[Component].lua` - thin wrapper that wires controller + view
- `Application/Hooks/use[Component]Controller.lua` - refs, motion hooks, animation orchestration, event composition
- `Presentation/Organisms/[Component]View.lua` - pure render tree, no orchestration hooks

Example:
- `SidePanel.lua` wraps
- `useSidePanelController.lua` handles spring/reduced-motion/hover logic
- `SidePanelView.lua` renders only from props

This keeps render files declarative while preserving rich motion behavior.

---

## Practical Heuristic

If a screen has more than simple composition (more than a couple handlers, delayed tasks, or chained side effects), extract that behavior into `use[Screen]Controller.lua`.

---

## Checklist

- [ ] `Presentation/Templates/[Screen].lua` (or App `Presentation/Screens/[Screen].lua`) is mostly declarative composition.
- [ ] Interaction/orchestration logic lives in `Application/Hooks/use[Screen]Controller.lua`.
- [ ] Child components receive only render-ready values and callbacks.
- [ ] Derived display formatting is moved to a ViewModel when it grows.
- [ ] Screen render files avoid direct atom/service calls.
- [ ] Screen render files avoid direct animation primitive orchestration.
- [ ] Animated organisms with complex motion use wrapper + controller + view split.
