# Frontend Hooks + ViewModel Contracts

Defines strict method contracts for frontend hooks and ViewModels.

Canonical architecture references:
- [../../architecture/frontend/HOOKS.md](../../architecture/frontend/HOOKS.md)
- [../../architecture/frontend/LAYERS.md](../../architecture/frontend/LAYERS.md)
- [../../architecture/frontend/DEPENDENCY_RULES.md](../../architecture/frontend/DEPENDENCY_RULES.md)

---

## Read Hook Contract (`useX`)

- Read hooks subscribe/select state only.
- Read hooks use subscription APIs (for example `ReactCharm.useAtom(...)`) and return read data.
- Read hooks do not expose mutation callbacks.

---

## Write Hook Contract (`useXActions`)

- Write hooks expose mutation/command callbacks only.
- Write hooks must not subscribe to atom state.
- Write hooks may call backend context methods or infrastructure clients for mutations.

---

## ViewModel Contract (`XViewModel`)

- ViewModels are pure data transforms (`input -> output`).
- ViewModels return frozen view data (`table.freeze(...)`).
- ViewModels own UI formatting/derived values, not side effects.

---

## Prohibitions

- Do not mix read subscription and write mutation responsibilities in the same hook.
- Do not call `useAtom` in write hooks.
- Do not place side-effect orchestration (timers, listeners, animation sequencing) in ViewModels.
- Do not mutate incoming ViewModel input tables.

---

## Failure Signals

- A `useXActions` hook contains atom subscription calls.
- A `useX` hook returns imperative mutation methods.
- ViewModel returns mutable tables or performs runtime side effects.
- Presentation files perform formatting logic that should be in ViewModel.

---

## Checklist

- [ ] Read and write hooks are separate files with separate responsibilities.
- [ ] `useX` subscribes/reads only.
- [ ] `useXActions` mutates/calls actions only.
- [ ] ViewModel output is frozen and side-effect free.
- [ ] Derived display formatting is centralized in ViewModel where non-trivial.
