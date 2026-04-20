Reconcile a bounded context to ensure it has required architecture pieces and identify gaps.

`$ARGUMENTS` format: `<ContextName> [--apply]`

- `<ContextName>`: backend context folder name in `src/ServerScriptService/Contexts/`
- `--apply` (optional): after reporting findings, implement safe, non-destructive fixes for missing wiring/structure issues

If `$ARGUMENTS` is empty, stop and ask for a context name.

## Goal

Produce a context-level architecture audit that goes beyond file-by-file review, then optionally apply safe fixes.

## Required pre-read

1. Read `.claude/MEMORIES.md`.
2. Read `.claude/documents/architecture/backend/DDD.md`, `CQRS.md`, `ERROR_HANDLING.md`, `STATE_SYNC.md`, and `SYSTEMS.md`.
3. Read `.claude/commands/review.md` and use its checklist as the baseline rule set.
4. Read the full target context tree:
   - `src/ServerScriptService/Contexts/<ContextName>/`
   - `src/ReplicatedStorage/Contexts/<ContextName>/`
5. Read persistence lifecycle contracts:
   - `src/ReplicatedStorage/Events/GameEvents/Misc/Persistence.lua`
   - `src/ServerScriptService/Persistence/PlayerLifecycleManager.lua`

## What to check

Run all `/review` checks, then also enforce context completeness:

### Context completeness checklist
- [ ] Context root has required structure (`Application/Commands`, `Application/Queries`, `<ContextName>Domain`, `Infrastructure/Persistence`, `Infrastructure/Services`; `Infrastructure/ECS` when needed).
- [ ] `<ContextName>Context.lua` exists and serves as pass-through boundary with Result/WrapContext rules.
- [ ] `Errors.lua` exists and is used for error strings.
- [ ] Shared types are centralized in `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua`.
- [ ] If context has atom sync behavior, `*SyncService` modules are in `Infrastructure/Persistence` (not `Infrastructure/Services`).
- [ ] If context persists player runtime state, handlers are wired to `GameEvents.Events.Persistence` (`ProfileLoaded`, `ProfileSaving`) and readiness uses `RegisterLoader`/`NotifyLoaded`.
- [ ] Commands/Queries/Policies are registered and resolved via registry wiring in context init/start paths.
- [ ] No dead scaffolding: required modules are either wired/used or explicitly documented as intentionally pending.

### Layer coverage rule

Do not mark context as reconciled if a required layer for shipped behavior is missing:
- Behavior with state change must have Application Command + Infrastructure mutation path.
- Behavior with business rule evaluation must include Domain policy/spec/service.
- Read-only behavior must be in Application Query and avoid Domain unless justified by documented exception.

## Output format

1. Findings grouped by severity: **Critical**, **Warning**, **Style**.
2. A reconciliation matrix with checkboxes for each completeness item.
3. Missing/partial items with exact file paths and concrete next action.
4. If `--apply` is present:
   - apply safe fixes,
   - list exactly what changed,
   - list unresolved blockers requiring user direction.
5. If everything passes, state: `Context reconciled: no gaps found.`

## Apply mode guardrails (`--apply`)

- Allowed: wiring fixes, folder/module placement corrections, missing registration, obvious path/category mismatches.
- Not allowed without explicit user request: large behavior refactors, destructive renames/deletes, semantic feature rewrites.
