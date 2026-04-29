---
name: implement-feature
description: Read when you need this skill reference template and workflow rules.
---

# Implement Feature

<!-- This is a repo-local prompt template. Codex does not automatically expose this as a slash command. Prefer the matching skill when available. -->

Implement the feature request in `$ARGUMENTS` end-to-end.

If `$ARGUMENTS` is empty, stop and ask the user to provide the feature request first.

---

## Goal

Deliver working code, not just a plan. Ensure required architecture/context files are read before editing.

---

## Required pre-read (must do before edits)

1. Read `.codex/MEMORIES.md`.
2. Read `.codex/documents/ONBOARDING.md` to select the correct architecture docs.
3. Read `.codex/Templates/README.md` and the relevant template before creating anything.
4. Determine scope from the request:
   - Backend scope: read `.codex/documents/architecture/backend/DDD.md`, `CQRS.md`, `ERROR_HANDLING.md`, and `STATE_SYNC.md`.
   - Frontend scope: read `.codex/documents/architecture/frontend/FRONTEND.md`, `LAYERS.md`, `HOOKS.md`, `COMPONENTS.md`, and `DEPENDENCY_RULES.md`.
   - Mixed scope: read both backend and frontend sets above.
   - If backend touches profile lifecycle, also read:
     - `src/ReplicatedStorage/Events/GameEvents/Misc/Persistence.lua`
     - `src/ServerScriptService/Persistence/SessionManager.lua`
     - `src/ServerScriptService/Persistence/PlayerLifecycleManager.lua`
   - If backend involves context or application scaffolding, also read:
     - `.codex/Templates/backend-context.md`
     - `.codex/Templates/backend-service.md`
     - `.codex/documents/methods/backend/BASE_CONTEXT_CONTRACTS.md`
     - `.codex/documents/methods/backend/BASE_APPLICATION_CONTRACTS.md`
   - If backend involves ECS infrastructure, also read:
     - `.codex/documents/methods/ECS/COMPONENT_RULES.md`
     - `.codex/documents/methods/ECS/ENTITY_FACTORY_RULES.md`
     - `.codex/documents/methods/ECS/WORLD_ISOLATION_RULES.md`
     - `.codex/documents/methods/ECS/SYSTEM_RULES.md`
     - `.codex/documents/methods/ECS/PHASE_AND_EXECUTION_RULES.md`
     - `.codex/documents/methods/ECS/TAG_RULES.md`
     - `.codex/documents/methods/ECS/INSTANCE_REVEAL_RULES.md`
     - `.codex/documents/methods/ECS/ECS_PERSISTENCE_RULES.md`
5. Read target code before changing it (no speculation):
   - Existing context entry: `src/ServerScriptService/Contexts/<ContextName>/<ContextName>Context.lua` when backend is involved.
   - Existing errors/types when backend is involved:
     - `src/ServerScriptService/Contexts/<ContextName>/Errors.lua`
     - `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua`
   - Existing feature entry: `src/StarterPlayerScripts/Contexts/<FeatureName>/Presentation/Templates/*` when frontend is involved.

---

## Scaffolding rules

- New backend bounded context: read `.codex/Templates/backend-context.md` first, then use `/new-context <Name>` conventions.
- New backend module inside an existing context: read `.codex/Templates/backend-service.md` first, then use `/new-service <Context> <Kind> <Name>` conventions.
- Any backend `*SyncService`: read `.codex/Templates/backend-syncservice.md` first, then use the sync-service path under `Infrastructure/Persistence`.
- New frontend feature slice: read `.codex/Templates/frontend-feature.md` first, then use `/new-feature <Name>` conventions.
- Do not invent parallel folder conventions when a scaffold command exists.

---

## Implementation requirements

1. Restate the feature in concrete engineering terms and proceed with implementation.
2. Implement complete vertical slice(s) needed for the request (wiring + behavior), not partial stubs.
3. Follow Result/WrapContext boundary rules for backend context methods.
4. Reuse `Errors.lua` constants (no inline error strings).
5. Keep context-shared backend types centralized in `<ContextName>Types.lua`.
6. Keep DDD/CQRS boundaries intact (queries read-only, commands mutate through infrastructure).
7. For backend context persistence, wire hydration/save through `GameEvents.Events.Persistence` (`ProfileLoaded`, `ProfileSaving`) and readiness through `PlayerLifecycleManager` (`RegisterLoader`/`NotifyLoaded`).
8. Use `BaseContext` for backend context entry modules and `BaseCommand` / `BaseQuery` for backend application modules.
9. Use ECS base classes for ECS infrastructure modules when relevant:
   - `BaseECSWorldService` for the per-context world service
   - `BaseECSComponentRegistry` for component/tag registration
   - `BaseECSEntityFactory` for entity creation, queries, and deferred destruction
   - `BaseSyncService` for persistence sync services that bridge atom state
10. Prefer shared utilities for common technical work before writing one-off helpers:
    - `SpatialQuery` for raycasts, overlap checks, visibility, range checks, target picking, or distance sorting
    - `PlacementPlus` for placement previews, snapping, footprint building, ground alignment, or placement validation
    - `ModelPlus` for pivot math, bounds/center reads, moving or aligning models, or reusable model traversal
11. Update registration/wiring where needed (`Context.lua`, registries, presentation indices, etc.).

---

## Required completion checklist (must be explicit in final response)

Use markdown checkboxes (`- [x]` / `- [ ]`) and include this section in the final response.

### Pre-read checklist
- [ ] Read required architecture docs for the task scope.
- [ ] Read target files before editing.
- [ ] Read persistence lifecycle files when backend profile lifecycle is touched.

### Backend enforcement checklist (when backend context work is involved)
- [ ] Context entry (`<ContextName>Context.lua`) updated/wired correctly.
- [ ] Application layer covered (`Application/Commands` and/or `Application/Queries`) for the requested behavior.
- [ ] Domain layer covered when business rules/validation are involved (`Domain/Services`, `Domain/Specs`, `Domain/Policies`, `Domain/ValueObjects` as needed).
- [ ] Infrastructure layer covered for runtime effects (`Infrastructure/Persistence`, `Infrastructure/Services`, `Infrastructure/ECS` as needed).
- [ ] Sync services are placed in `Infrastructure/Persistence` (not `Infrastructure/Services`).
- [ ] Errors reuse `Errors.lua` constants; no inline error strings.
- [ ] Context-shared shapes use `<ContextName>Types.lua`.
- [ ] Result/WrapContext boundary rules are respected.

### Frontend enforcement checklist (when frontend work is involved)
- [ ] Layer boundaries respected (`Infrastructure` -> `Application` -> `Presentation`).
- [ ] Read/write hook separation preserved.
- [ ] ViewModel + screen wiring updated for shipped behavior.

### Validation checklist
- [ ] Targeted lint/build checks were run, or explicitly marked as not run with reason.
- [ ] Any incomplete items are listed with concrete blockers.

---

## Completion gate

Do not claim the feature is complete if any required checklist item is unchecked.
If an item is intentionally out of scope, mark it unchecked and provide a one-line reason.

---

## Validation requirements

1. Run targeted checks after edits:
   - Lint touched Luau files (prefer `selene` on touched paths when available).
   - Run any relevant build/sync command used in this repo when needed.
2. If validation cannot be run, explicitly state what could not be run and why.

---

## Response format

1. What was implemented.
2. Files changed and why.
3. Validation run and outcomes.
4. Required completion checklist (with checkboxes).
5. Any follow-up risks or TODOs that remain.
