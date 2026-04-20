Implement the feature request in `$ARGUMENTS` end-to-end.

If `$ARGUMENTS` is empty, stop and ask the user to provide the feature request first.

## Goal

Deliver working code, not just a plan. Ensure required architecture/context files are read before editing.

## Required pre-read (must do before edits)

1. Read `.claude/MEMORIES.md`.
2. Read `.claude/documents/ONBOARDING.md` to select the correct architecture docs.
3. Determine scope from the request:
   - Backend scope: read `.claude/documents/architecture/backend/DDD.md`, `CQRS.md`, `ERROR_HANDLING.md`, and `STATE_SYNC.md`.
   - Frontend scope: read `.claude/documents/architecture/frontend/FRONTEND.md`, `LAYERS.md`, `HOOKS.md`, `COMPONENTS.md`, and `DEPENDENCY_RULES.md`.
   - Mixed scope: read both backend and frontend sets above.
4. Read target code before changing it (no speculation):
   - Existing context entry: `src/ServerScriptService/Contexts/<ContextName>/<ContextName>Context.lua` when backend is involved.
   - Existing errors/types when backend is involved:
     - `src/ServerScriptService/Contexts/<ContextName>/Errors.lua`
     - `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua`
   - Existing feature entry: `src/StarterPlayerScripts/Contexts/<FeatureName>/Presentation/Templates/*` when frontend is involved.

## Scaffolding rules

- New backend bounded context: use `/new-context <Name>` conventions.
- New backend module inside an existing context: use `/new-service <Context> <Kind> <Name>` conventions.
- New frontend feature slice: use `/new-feature <Name>` conventions.
- Do not invent parallel folder conventions when a scaffold command exists.

## Implementation requirements

1. Restate the feature in concrete engineering terms and proceed with implementation.
2. Implement complete vertical slice(s) needed for the request (wiring + behavior), not partial stubs.
3. Follow Result/WrapContext boundary rules for backend context methods.
4. Reuse `Errors.lua` constants (no inline error strings).
5. Keep context-shared backend types centralized in `<ContextName>Types.lua`.
6. Keep DDD/CQRS boundaries intact (queries read-only, commands mutate through infrastructure).
7. Update registration/wiring where needed (`Context.lua`, registries, presentation indices, etc.).

## Validation requirements

1. Run targeted checks after edits:
   - Lint touched Luau files (prefer `selene` on touched paths when available).
   - Run any relevant build/sync command used in this repo when needed.
2. If validation cannot be run, explicitly state what could not be run and why.

## Response format

1. What was implemented.
2. Files changed and why.
3. Validation run and outcomes.
4. Any follow-up risks or TODOs that remain.
