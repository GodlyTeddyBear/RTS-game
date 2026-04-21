# Frontend Template + Organism Contracts

Defines strict method contracts for template/screen composition and organism boundaries.

Canonical architecture references:
- [../../architecture/frontend/COMPONENTS.md](../../architecture/frontend/COMPONENTS.md)
- [../../architecture/frontend/SCREEN_TEMPLATES.md](../../architecture/frontend/SCREEN_TEMPLATES.md)
- [../../architecture/frontend/ANIMATION_PATTERN.md](../../architecture/frontend/ANIMATION_PATTERN.md)
- [../../architecture/frontend/DEPENDENCY_RULES.md](../../architecture/frontend/DEPENDENCY_RULES.md)

---

## Template/Screen Contract

- Templates/screens are composition and prop-wiring boundaries.
- Templates call hooks and construct ViewModels, then pass render-ready props to organisms.
- Templates stay declarative; orchestration logic belongs in controller hooks.

---

## Organism Contract

- Organisms are feature-local complex UI components.
- Organisms own local UI composition for feature-specific regions.
- Complex list/grid child-building logic belongs in dedicated organisms, not templates.

---

## Animation Boundary Contract

- Screen/template files do not orchestrate animation primitives directly.
- Animated components use wrapper + controller + view separation when behavior is non-trivial.

---

## Prohibitions

- Do not import infrastructure/services directly in template or organism render files.
- Do not place chained side effects, timers, or delayed navigation flows directly in templates.
- Do not build complex list/grid child trees inline in templates.
- Do not perform direct animation primitive orchestration (`TweenService:Create`, `spr.target`, `spr.completed`) in templates.
- Do not import feature A presentation modules into feature B (no cross-feature imports).

---

## Failure Signals

- Template file grows orchestration-heavy with timer/side-effect sequencing.
- Template loops and assembles a complex grid/list tree inline instead of delegating to organism.
- Template or organism imports infrastructure atom/services directly.
- Screen/template contains direct animation primitive calls.
- Feature presentation imports another feature slice directly.

---

## Checklist

- [ ] Template/screen remains composition-first and declarative.
- [ ] Orchestration callbacks are delegated to controller hooks.
- [ ] Complex list/grid child-building is extracted to organisms.
- [ ] Templates avoid direct infrastructure/service imports.
- [ ] Templates avoid direct animation primitive orchestration.
- [ ] Cross-feature presentation imports are absent.
