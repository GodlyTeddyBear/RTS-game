# Frontend Controller + Infrastructure Contracts

Defines strict contracts for UI controller hooks and frontend infrastructure boundaries.

Canonical architecture references:
- [../../architecture/frontend/LAYERS.md](../../architecture/frontend/LAYERS.md)
- [../../architecture/frontend/HOOKS.md](../../architecture/frontend/HOOKS.md)
- [../../architecture/frontend/ANIMATION_PATTERN.md](../../architecture/frontend/ANIMATION_PATTERN.md)
- [../../architecture/frontend/DEPENDENCY_RULES.md](../../architecture/frontend/DEPENDENCY_RULES.md)

---

## Core Rules

- Follow the required contracts in the sections below.
- Treat Prohibitions, Failure Signals, and Checklist as pass/fail requirements.

---

## Screen/UI Controller Contract

- Screen controller hooks (`useXController`) own screen-level interaction state and orchestration.
- Controller hooks own side effects such as delayed flows, event wiring, and callback composition.
- Controller hooks expose a small callback/state surface to templates/organisms.


---
## Infrastructure Contract (Frontend)

- Infrastructure modules own atom creation/sync wiring and service clients.
- Presentation modules never mutate atoms directly; mutations flow through application write hooks/controllers.
- Feature slice boundaries remain isolated (no direct feature-to-feature imports).


---
## Side-Effect Boundary Contract

- Runtime side effects (input listeners, loops, timer sequencing, animation orchestration) are owned by controller hooks or infrastructure modules.
- Pure view files remain side-effect free and Presentation-only.


---
## Prohibitions

- Do not place service calls or atom mutation logic directly in presentation views.
- Do not import application hooks in pure `*View.lua` files.
- Do not place long-lived runtime listeners in templates without controller ownership/cleanup.
- Do not let global `App` modules depend on feature-local modules.


---
## Failure Signals

- Template/organism mutates state directly through atom references.
- Pure view file imports controller hooks or service modules.
- Side-effect cleanup is missing from controller-managed delayed/listener workflows.
- App-level presentation imports feature-local components.


---
## Checklist

- [ ] Controller hooks own side effects and orchestration for the screen/component.
- [ ] Infrastructure owns atom sync/service client implementation.
- [ ] Presentation views are declarative and side-effect free.
- [ ] Pure view modules avoid application/infrastructure imports.
- [ ] App-level modules do not import feature-local modules.

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

