<!-- This is a repo-local prompt template. Read this before creating a backend sync service. -->

# Backend SyncService Template

Create a backend sync service for `$ARGUMENTS`.

`$ARGUMENTS` format: `<ContextName> <Name>`

If `$ARGUMENTS` is empty, stop and ask the user to provide the context and sync service name first.

---

## Read First

1. Read `.codex/MEMORIES.md`.
2. Read `.codex/documents/ONBOARDING.md`.
3. Read `.codex/Templates/README.md` and this template before creating files.
4. Read the target context tree and the target context entry before creating anything.
5. Read `.codex/commands/new-service.md` and `.codex/commands/implement-feature.md` if you need the current scaffold shape.
6. Read `.codex/documents/architecture/backend/BACKEND.md`, `.codex/documents/architecture/backend/ERROR_HANDLING.md`, and `.codex/documents/methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md`.
7. Read `.codex/documents/methods/ECS/ECS_PERSISTENCE_RULES.md`.

---

## Create

- Create the sync service under `src/ServerScriptService/Contexts/<ContextName>/Infrastructure/Persistence/`.
- Use the repo's sync-service base class and persistence bridge pattern when applicable.
- Keep atom read/write orchestration in the sync service, not in context bridges.
- Add any required shared types to `<ContextName>Types.lua`.
- Wire the sync service into the context entry or registry if the context exposes it publicly.

---

## Rules

- `*SyncService` modules must live in `Infrastructure/Persistence`.
- Do not place sync services in `Infrastructure/Services`.
- Keep persistence boundaries separate from gameplay/domain logic.
- Reuse existing context-shared types and errors.
- Use `Result` for fallible persistence boundaries.
- Do not invent a new sync-service folder convention.

---

## Output

- Report the file created.
- Report the context wiring added.
- Report any persistence lifecycle integration added.
